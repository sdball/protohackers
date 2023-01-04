defmodule Protohackers.EchoServer do
  use GenServer

  require Logger

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(:no_state) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      # receive data as binaries (instead of lists)
      mode: :binary,
      # block on `:gen_tcp.recv/2` until data is available
      active: false,
      # allow reusing the address if the listener crashes
      reuseaddr: true,
      # keep the peer socket open after the client closes its writes
      exit_on_close: false
    ]

    case :gen_tcp.listen(11235, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting echo server on port 11235")
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

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
        Logger.error("Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  defp handle_connection(socket) do
    case receive_until_closed(socket, _buffer = "") do
      {:ok, data} ->
        :gen_tcp.send(socket, data)

      {:error, :exceeded_write_limit} ->
        :gen_tcp.send(socket, "ERR_EXCEEDED_WRITE_LIMIT")

      {:error, reason} ->
        Logger.error("Failed to receive data #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  @buffer_size_limit _100_kb = 1024 * 100

  defp receive_until_closed(socket, buffer) do
    buffered_size = IO.iodata_length(buffer)

    case :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_millis = 10_000) do
      {:ok, data} when buffered_size + byte_size(data) > @buffer_size_limit ->
        {:error, :exceeded_write_limit}

      {:ok, data} ->
        receive_until_closed(socket, [buffer, data])

      {:error, :closed} ->
        {:ok, buffer}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
