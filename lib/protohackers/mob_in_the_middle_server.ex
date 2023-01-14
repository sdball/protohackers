defmodule Protohackers.MobInTheMiddleServer do
  use GenServer

  require Logger

  @boguscoin ~r/^7[a-zA-Z0-9]{25,34}$/

  def start_link(port \\ 11240) do
    GenServer.start_link(__MODULE__, port)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(port) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      # receive data as binaries (instead of lists)
      mode: :binary,
      # receive incoming packets as messages
      active: true,
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
      Logger.info("Starting MobRoomServer on port #{port}")

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
    with {:ok, socket} <- :gen_tcp.accept(state.listen_socket),
         {:ok, task_pid} <-
           Task.Supervisor.start_child(state.supervisor, fn ->
             handle_connection(socket)
           end) do
      :gen_tcp.controlling_process(socket, task_pid)
      {:noreply, state, {:continue, :accept}}
    else
      {:error, reason} ->
        Logger.error("[MobRoomServer] Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  def handle_connection(client) do
    upstream_server = Application.get_env(:protohackers, __MODULE__)

    {:ok, upstream} =
      :gen_tcp.connect(
        upstream_server[:host],
        upstream_server[:port],
        [:binary, active: true]
      )

    handle_messages(client, upstream)

    :gen_tcp.close(upstream)
    :gen_tcp.close(client)
  end

  def handle_messages(client, upstream) do
    receive do
      {:tcp, ^client, message} ->
        rewritten = rewrite(message)
        :gen_tcp.send(upstream, rewritten)
        handle_messages(client, upstream)

      {:tcp, ^upstream, message} ->
        rewritten = rewrite(message)
        :gen_tcp.send(client, rewritten)
        handle_messages(client, upstream)

      {:tcp_closed, ^client} ->
        Logger.info("[MOB] client disconnected")
        :ok

      {:tcp_closed, ^upstream} ->
        Logger.info("[MOB] upstream disconnected")
        :ok
    end
  end

  def rewrite(message) do
    message
    |> String.split(" ")
    |> Enum.map(& Regex.replace(@boguscoin, &1, "7YWHMfk9JZe0LM0g1ZauHuiSxhI"))
    |> Enum.join(" ")
  end
end
