defmodule Protohackers.SpeedDaemon.Connection do
  # TODO rework as a state machine
  use GenServer, restart: :temporary

  alias Protohackers.SpeedDaemon.{CentralTicketDispatcher, DispatchersRegistry, BinaryProtocol}

  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  defstruct [:socket, :type, :heartbeat_timer, buffer: <<>>]

  @impl true
  def init(socket) do
    Logger.debug("SpeedDaemon.Connection.client_connected")
    {:ok, %__MODULE__{socket: socket}}
  end

  @impl true
  def handle_info(message, state)

  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    :ok = :inet.setopts(socket, active: :once)
    state = update_in(state.buffer, &(&1 <> data))
    parse_buffer(state)
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("SpeeedDaemon.Connection.tcp_error reason=#{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Logger.debug("SpeeedDaemon.Connection.tcp_closed")
    {:stop, :normal, state}
  end

  def handle_info(:send_heartbeat, %__MODULE__{} = state) do
    send_message(state, %BinaryProtocol.Heartbeat{})
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:dispatch_ticket, ticket},
        %__MODULE__{type: %BinaryProtocol.IAmDispatcher{}} = state
      ) do
    send_message(state, ticket)
    {:noreply, state}
  end

  # -- internal --

  defp parse_buffer(%__MODULE__{} = state) do
    case BinaryProtocol.decode(state.buffer) do
      {:ok, message, rest} ->
        Logger.debug("SpeedDaemon.Connection.decoded_message message=#{inspect(message)}")
        state = put_in(state.buffer, rest)

        case handle_message(state, message) do
          {:ok, state} ->
            parse_buffer(state)

          {:error, message} ->
            handle_client_error(state, message)
        end

      :partial ->
        {:noreply, state}

      :error ->
        handle_client_error(state, "invalid protocol message")
        {:stop, :normal, state}
    end
  end

  defp handle_message(
         %__MODULE__{type: %BinaryProtocol.IAmCamera{} = camera} = state,
         %BinaryProtocol.Plate{} = plate
       ) do
    CentralTicketDispatcher.register_observation(
      camera.road,
      camera.mile,
      plate.plate,
      plate.timestamp
    )

    {:ok, state}
  end

  defp handle_message(%__MODULE__{type: _non_camera_client}, %BinaryProtocol.Plate{}) do
    {:error, "You cannot send a plate because you are not a camera"}
  end

  defp handle_message(state, %BinaryProtocol.WantHeartbeat{interval: interval}) do
    interval_millis = interval * 100

    if state.heartbeat_timer do
      :timer.cancel(state.heartbeat_timer)
    end

    if interval > 0 do
      {:ok, heartbeat_timer} = :timer.send_interval(interval_millis, :send_heartbeat)
      {:ok, %__MODULE__{state | heartbeat_timer: heartbeat_timer}}
    else
      {:ok, %__MODULE__{state | heartbeat_timer: nil}}
    end
  end

  defp handle_message(%__MODULE__{type: nil} = state, %BinaryProtocol.IAmCamera{} = camera) do
    CentralTicketDispatcher.add_road(camera.road, camera.limit)
    Logger.metadata(type: :camera, road: camera.road, mile: camera.mile)
    {:ok, %__MODULE__{state | type: camera}}
  end

  defp handle_message(%__MODULE__{type: _given_type}, %BinaryProtocol.IAmCamera{}) do
    {:error, "client type is already registered"}
  end

  defp handle_message(
         %__MODULE__{type: nil} = state,
         %BinaryProtocol.IAmDispatcher{} = dispatcher
       ) do
    Enum.each(dispatcher.roads, fn road ->
      {:ok, _} = Registry.register(DispatchersRegistry, road, :dispatcher)
    end)

    Logger.metadata(type: :dispatcher)
    {:ok, %__MODULE__{state | type: dispatcher}}
  end

  defp handle_message(%__MODULE__{type: _given_type}, %BinaryProtocol.IAmDispatcher{}) do
    {:error, "client type is already registered"}
  end

  defp handle_message(%__MODULE__{}, _message) do
    {:error, "invalid message"}
  end

  defp send_message(%__MODULE__{socket: socket}, message) do
    Logger.debug("SpeedDaemon.Connection.client_message message=#{inspect(message)}")
    :gen_tcp.send(socket, BinaryProtocol.encode(message))
  end

  defp handle_client_error(state, message) do
    Logger.debug("SLS.Client.client_error message=#{inspect(message)}")
    send_message(state, %BinaryProtocol.Error{message: message})
    {:stop, :normal, state}
  end
end
