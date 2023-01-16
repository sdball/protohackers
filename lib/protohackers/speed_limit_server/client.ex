defmodule Protohackers.SpeedLimitServer.Client do
  alias Protohackers.SpeedLimitServer.{Camera, Dispatcher, PlateReading, Database}
  use GenServer
  require Logger

  @error 0x10
  @plate 0x20
  @ticket 0x21
  @want_heartbeat 0x40
  @heartbeat 0x41
  @camera 0x80
  @dispatcher 0x81

  defstruct [:socket, :heartbeat_interval, :camera, :dispatcher, buffer: ""]

  def start(socket) do
    GenServer.start(__MODULE__, socket: socket)
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket: socket)
  end

  def send_ticket(pid, ticket) do
    GenServer.call(pid, {:ticket, ticket})
  end

  @impl true
  def init(socket: socket) do
    Logger.debug("SLS.Client.init pid=#{inspect(self())} socket=#{inspect(socket)}")

    state = %__MODULE__{
      socket: socket
    }

    activate(state.socket)

    {:ok, state}
  end

  @impl true
  def handle_continue(:process, state = %__MODULE__{}) do
    Logger.debug("SLS.ClientMessage.buffer #{inspect(state.buffer)}")

    case client_message(state.buffer) do
      {:ok, camera: camera, rest: rest} ->
        if is_nil(state.dispatcher) and is_nil(state.camera) do
          {:noreply, %{state | camera: camera, buffer: rest}, {:continue, :process}}
        else
          handle_client_error(state)
        end

      {:ok, dispatcher: dispatcher, rest: rest} ->
        if is_nil(state.dispatcher) and is_nil(state.camera) do
          :ok = Database.connect_dispatcher(self(), dispatcher.roads)
          {:noreply, %{state | dispatcher: dispatcher, buffer: rest}, {:continue, :process}}
        else
          handle_client_error(state)
        end

      {:ok, {:plate, plate, timestamp}, remaining} ->
        if state.camera do
          plate_reading =
            PlateReading.build(
              plate,
              timestamp,
              state.camera.road,
              state.camera.mile,
              state.camera.limit
            )

          Logger.info("SLS.Camera.plate_reading plate_reading=#{inspect(plate_reading)}")
          :ok = Database.plate_reading(plate_reading)
          {:noreply, %{state | buffer: remaining}, {:continue, :process}}
        else
          handle_client_error(state)
        end

      {:heartbeat, 0, remaining} ->
        {:noreply, %{state | heartbeat_interval: nil, buffer: remaining}, {:continue, :process}}

      {:heartbeat, interval, remaining} ->
        Process.send_after(self(), :heartbeat, interval)

        {:noreply, %{state | heartbeat_interval: interval, buffer: remaining},
         {:continue, :process}}

      :partial ->
        activate(state.socket)
        {:noreply, state}

      {:error, :invalid} ->
        handle_client_error(state)

      _unknown ->
        Logger.error("SLS.Camera.unknown_processing_result")
        handle_server_error(state)
    end
  end

  @impl true
  def handle_call({:ticket, ticket}, _from, state) do
    result = handle_send_ticket(state.socket, ticket)
    {:reply, result, state}
  end

  @impl true
  def handle_info({:tcp, _socket, message}, state) do
    new_state = %{state | buffer: state.buffer <> message}
    {:noreply, new_state, {:continue, :process}}
  end

  def handle_info({:tcp_closed, _port}, state = %{dispatcher: dispatcher})
      when not is_nil(dispatcher) do
    :ok = Database.disconnect_dispatcher(self())
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, _port}, state) do
    {:stop, :normal, state}
  end

  # time to send the client a heartbeat
  def handle_info(:heartbeat, state)
      when not is_nil(state.heartbeat_interval) and state.heartbeat_interval > 0 do
    Logger.info("SLS.Client.send_heartbeat interval=#{state.heartbeat_interval}ms")
    handle_send_heartbeat(state.socket)
    Process.send_after(self(), :heartbeat, state.heartbeat_interval)
    {:noreply, state}
  end

  # time send the client a heartbeat but the client has cancelled the request
  def handle_info(:heartbeat, state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.error("SLS.Client.unexpected_message message=#{inspect(msg)}")
    {:noreply, state}
  end

  # client message parsing
  def client_message(<<@camera, road::16, mile::16, limit::16, rest::binary>>) do
    Logger.info(
      "SLS.ClientMessage.camera road=#{inspect(road)} mile=#{inspect(mile)} limit=#{inspect(limit)}"
    )

    {:ok, camera: Camera.new(road, mile, limit), rest: rest}
  end

  def client_message(<<@camera, _rest::binary>>), do: :partial

  def client_message(<<@dispatcher, roads_count::8, rest::binary>>) do
    case rest do
      <<roads::binary-size(roads_count * 2), rest::binary>> ->
        Logger.info("SLS.ClientMessage.dispatcher roads=#{inspect(roads)}")
        {:ok, dispatcher: Dispatcher.new(roads), rest: rest}

      _incomplete ->
        :partial
    end
  end

  def client_message(<<@dispatcher, _rest::binary>>), do: :partial

  def client_message(<<@plate, length, rest::binary>>) do
    case rest do
      <<plate::binary-size(length), timestamp::32, remaining::binary>> ->
        Logger.info(
          "SLS.ClientMessage.plate plate=#{inspect(plate)} timestamp=#{inspect(timestamp)}"
        )

        {:ok, {:plate, plate, timestamp}, remaining}

      _incomplete ->
        :partial
    end
  end

  def client_message(<<@plate, _rest::binary>>), do: :partial

  def client_message(<<@want_heartbeat, interval_deciseconds::32, rest::binary>>) do
    millis = interval_deciseconds * 100
    Logger.info("SLS.ClientMessage.want_heartbeat deciseconds=#{interval_deciseconds}")
    {:heartbeat, millis, rest}
  end

  def client_message(<<@want_heartbeat, _rest::binary>>) do
    :partial
  end

  def client_message(""), do: :partial

  def client_message(_invalid), do: {:error, :invalid}

  defp handle_client_error(state) do
    Logger.info("SLS.Client.client_error")
    error = <<@error>> <> protocol_string("invalid client message")
    :gen_tcp.send(state.socket, error)
    :gen_tcp.shutdown(state.socket, :write)
    {:stop, :normal, state}
  end

  defp handle_server_error(state) do
    Logger.info("SLS.Client.server_error")
    error = <<@error>> <> protocol_string("server error")
    :gen_tcp.send(state.socket, error)
    :gen_tcp.shutdown(state.socket, :write)
    {:stop, :error, state}
  end

  defp handle_send_heartbeat(socket) do
    :gen_tcp.send(socket, <<@heartbeat>>)
  end

  defp handle_send_ticket(socket, ticket) do
    Logger.info("SLS.Client.send_ticket ticket=#{inspect(ticket)}")

    packet =
      <<@ticket>> <>
        protocol_string(ticket.plate) <>
        <<
          ticket.road::16,
          ticket.mile1::16,
          ticket.timestamp1::32,
          ticket.mile2::16,
          ticket.timestamp2::32,
          ticket.speed::16
        >>

    :gen_tcp.send(socket, packet)
  end

  defp protocol_string(string) do
    length = byte_size(string)
    <<length>> <> string
  end

  defp activate(socket) do
    Logger.debug("SLS.Client.activate_socket socket=#{inspect(socket)} pid=#{inspect(self())}")
    :inet.setopts(socket, active: :once)
  end
end
