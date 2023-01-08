defmodule Protohackers.ChatRoomServer do
  @moduledoc """
  TCP-based chat room server implementation

  Each message is a single line of ASCII text terminated by a newline character
  ('\n', or ASCII 10).

  Clients can send multiple messages per connection.

  All messages are raw ASCII text, not wrapped up in JSON or any other format.

  ## Joining the chat as a new user

  When a client connects to the server, it does not yet have a name and is not
  considered to have joined.

  The server will prompt the user by sending a single message asking for a name.

  ```
  Welcome to C.H.A.T. What name would you like?
  ```

  The first message from a client sets the user's name, which must contain
  at least 1 character, and must consist entirely of alphanumeric characters
  (uppercase, lowercase, and digits).

  Once the user has a name, they have joined the chat room and the server will
  announce their presence to other users.

  The server will send the new user a message that lists all present users'
  names, not including the new user, and not including any users who have
  already left. The wording of this message may vary but will lead with an
  asterisk `*` character.

  ```
  * The chat room: susan, mark, dave, amy
  ```

  The room list will be sent even if the room is empty.

  All subsequent messages from the server will be chat messages originating from
  other connected users.

  ## Chat messages

  After the naming/joining process is complete when a client sends a message to
  the server it will be a chat message.

  The server will relay chat messages to all other connected clients in the
  following format:

  ```
  [name] message
  ```

  The message sender will NOT get an echoed copy of their own message.

  ## Notification of new user joins

  When a user joins the chat room all other joined users will receive a message
  from the server informing them a new user has joined.

  The new user joined message wording will vary but will lead with an asterisk
  `*` character and contain the user's name.

  ```
  * alice has joined the room
  ```

  ## Notification of joined user departures

  When a joined user is disconnected for any reason other joined users will be
  notified of their departure.

  The user left message wording will vary but will lead with an asterisk `*`
  character and contain the user's name.

  ```
  * alice has left the room
  ```
  """

  use GenServer

  require Logger

  def start_link(port \\ 11238) do
    GenServer.start_link(__MODULE__, port)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(port) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    {:ok, _pid} =
      Registry.start_link(
        keys: :duplicate,
        name: Registry.ChatRoom,
        partitions: System.schedulers_online()
      )

    listen_options = [
      # receive data as binaries (instead of lists)
      mode: :binary,
      # explicitly retrieve packets by calling `:gen_tcp.recv/2`
      # (by default incoming packets would be sent as messages)
      active: false,
      # allow reusing the address if the listener crashes
      reuseaddr: true,
      # keep the peer socket open after the client closes its writes
      exit_on_close: false,
      # automatically split inputs by newline
      packet: :line,
      # increase default buffer to 10KB
      buffer: 1024 * 10
    ]

    with {:ok, listen_socket} <- :gen_tcp.listen(port, listen_options) do
      Logger.info("Starting ChatRoomServer on port #{port}")

      state = %__MODULE__{
        listen_socket: listen_socket,
        supervisor: supervisor
      }

      {:ok, state, {:continue, :accept}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn ->
          handle_connection(socket)
        end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("[ChatRoomServer] Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  # -- core ------------------------------------------------------------------
  def broadcast_user_joined(username) do
    Registry.dispatch(Registry.ChatRoom, "general", fn users ->
      users
      |> Enum.reject(fn {_pid, name} ->
        name == username
      end)
      |> Enum.each(fn {pid, _name} ->
        send(pid, {:broadcast_user_joined, username})
      end)
    end)

    Logger.info("#{username} joined")
  end

  def list_previously_joined_users(socket, username) do
    other_users =
      Registry.lookup(Registry.ChatRoom, "general")
      |> Enum.map(&elem(&1, 1))
      |> Enum.reject(&(&1 == username))
      |> Enum.sort()
      |> Enum.join(", ")

    if other_users == "" do
      :gen_tcp.send(socket, "* You have joined the room\n")
    else
      :gen_tcp.send(socket, "* You have joined the room with: #{other_users}\n")
    end
  end

  def broadcast_user_left(username) do
    Registry.dispatch(Registry.ChatRoom, "general", fn users ->
      users
      |> Enum.reject(fn {_pid, name} ->
        name == username
      end)
      |> Enum.each(fn {pid, _name} ->
        send(pid, {:broadcast_user_left, username})
      end)
    end)

    Logger.info("#{username} left")
  end

  def chat_room(socket, username) do
    with {:ok, message} <- receive_input(socket) do
      user_message(username, message)
      chat_room(socket, username)
    else
      {:error, :unprintable} ->
        chat_room(socket, username)

      error ->
        error
    end
  end

  def user_message(username, message) do
    Registry.dispatch(Registry.ChatRoom, "general", fn users ->
      users
      |> Enum.reject(fn {_pid, name} ->
        name == username
      end)
      |> Enum.each(fn {pid, _name} ->
        send(pid, {:user_message, username, message})
      end)
    end)
  end

  def check_name(name) do
    with {:ok, name} <- check_name_format(name),
         {:ok, name} <- check_available_name(name) do
      {:ok, name}
    else
      error ->
        error
    end
  end

  def check_name_format(name) when byte_size(name) > 0 and byte_size(name) < 30 do
    if Regex.match?(~r|^[a-zA-Z0-9]+$|, name) do
      {:ok, name}
    else
      {:error, :rejected_name}
    end
  end

  def check_name_format(_name), do: {:error, :rejected_name}

  def check_available_name(name) do
    Registry.lookup(Registry.ChatRoom, "general")
    |> Enum.map(&elem(&1, 1))
    |> Enum.into(MapSet.new())
    |> MapSet.member?(name)
    |> case do
      true ->
        {:error, :name_already_taken}

      false ->
        {:ok, name}
    end
  end

  # -- server ----------------------------------------------------------------

  def handle_connection(socket) do
    case join_chat(socket) do
      {:ok, username} ->
        broadcast_user_joined(username)
        list_previously_joined_users(socket, username)
        chat_room(socket, username)
        broadcast_user_left(username)

      {:error, reason} ->
        Logger.error("[ChatRoomServer] failed to join #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  def join_chat(socket) do
    :gen_tcp.send(socket, "Welcome! What name would you like?\n")

    with {:ok, name} <- receive_input(socket),
         {:ok, name} <- check_name(name),
         {:ok, _pid} <- Registry.register(Registry.ChatRoom, "general", name) do
      {:ok, name}
    else
      {:error, reason = :rejected_name} ->
        :gen_tcp.send(socket, "Sorry that is an rejected name\n")
        {:error, reason}

      {:error, reason = :name_already_taken} ->
        :gen_tcp.send(socket, "Sorry that name is already taken\n")
        {:error, reason}

      error ->
        error
    end
  end

  def receive_input(socket) do
    with {:ok, input} <- :gen_tcp.recv(socket, 0, 100),
         true <- String.printable?(input) do
      {:ok, String.replace(input, ~r|\s*$|, "")}
    else
      false ->
        {:error, :unprintable}

      {:error, :timeout} ->
        receive do
          {:broadcast_user_left, username} ->
            :gen_tcp.send(socket, "* #{username} left\n")
            receive_input(socket)

          {:broadcast_user_joined, username} ->
            :gen_tcp.send(socket, "* #{username} joined\n")
            receive_input(socket)

          {:user_message, username, message} ->
            :gen_tcp.send(socket, "[#{username}] #{message}\n")
            receive_input(socket)
        after
          100 ->
            receive_input(socket)
        end

      error ->
        error
    end
  end
end
