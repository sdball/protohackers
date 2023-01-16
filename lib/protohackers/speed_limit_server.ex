defmodule Protohackers.SpeedLimitServer do
  alias Protohackers.SpeedLimitServer.Client
  use GenServer
  require Logger

  def start_link(port \\ 11241) do
    GenServer.start_link(__MODULE__, port)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(port) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 500)
    {:ok, _database_pid} = Protohackers.SpeedLimitServer.Database.start_link()

    listen_options = [
      # receive data as binaries (instead of lists)
      mode: :binary,
      # only receive data from the socket by explicitly calling gen_tcp.recv
      active: false,
      # allow reusing the address if the listener crashes
      reuseaddr: true,
      # keep the peer socket open after the client closes its writes
      exit_on_close: false
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting SpeedLimitServer on port #{port}")
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    with {:ok, socket} <- :gen_tcp.accept(state.listen_socket),
         {:ok, pid} <- start_client(socket) do
      dbg(socket)
      dbg(pid)
      Logger.info("SLS.client_started pid=#{inspect(pid)}")
      :gen_tcp.controlling_process(socket, pid) |> dbg()
      {:noreply, state, {:continue, :accept}}
    else
      {:error, reason} ->
        Logger.error("[SpeedLimitServer] Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  defp start_client(socket) do
    Client.start(socket)
  end
end
