defmodule Protohackers.MITM.Connection do
  use GenServer, restart: :transient

  require Logger

  alias Protohackers.MITM.Boguscoin

  def start_link(client_socket) do
    GenServer.start_link(__MODULE__, client_socket)
  end

  defstruct [:client_socket, :upstream_socket]

  @impl true
  def init(client_socket) do
    upstream_server = Application.get_env(:protohackers, Protohackers.MobInTheMiddleServer)

    case :gen_tcp.connect(upstream_server[:host], upstream_server[:port], [:binary, active: :once]) do
      {:ok, upstream_socket} ->
        Logger.debug("MITM.Connection started connection client_socket=#{inspect(client_socket)}")
        {:ok, %__MODULE__{client_socket: client_socket, upstream_socket: upstream_socket}}

      {:error, reason} ->
        Logger.error(
          "MITM.Connect failed to connect to upstream server reason=#{inspect(reason)}"
        )

        {:stop, reason}
    end
  end

  @impl true
  def handle_info(message, state)

  def handle_info(
        {:tcp, client_socket, data},
        %__MODULE__{client_socket: client_socket} = state
      ) do
    :ok = :inet.setopts(client_socket, active: :once)
    Logger.debug("MITM.Connection received tcp data from client #{inspect(data)}")
    :gen_tcp.send(state.upstream_socket, Boguscoin.rewrite(data))
    {:noreply, state}
  end

  def handle_info(
        {:tcp, upstream_socket, data},
        %__MODULE__{upstream_socket: upstream_socket} = state
      ) do
    :ok = :inet.setopts(upstream_socket, active: :once)
    Logger.debug("MITM.Connection received tcp data from upstream #{inspect(data)}")
    :gen_tcp.send(state.client_socket, Boguscoin.rewrite(data))
    {:noreply, state}
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{} = state)
      when socket in [state.client_socket, state.upstream_socket] do
    Logger.error("MITM.Connection received tcp error #{inspect(reason)}")
    :gen_tcp.close(state.client_socket)
    :gen_tcp.close(state.upstream_socket)
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{} = state)
      when socket in [state.client_socket, state.upstream_socket] do
    Logger.debug("MITM.Connection tcp connection closed")
    :gen_tcp.close(state.client_socket)
    :gen_tcp.close(state.upstream_socket)
    {:stop, :normal, state}
  end

  def handle_info(message, state) do
    Logger.error("MITM.Connection unexpected elixir message message=#{inspect(message)}")
    {:noreply, state}
  end
end
