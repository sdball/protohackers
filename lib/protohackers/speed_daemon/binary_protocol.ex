defmodule Protohackers.SpeedDaemon.BinaryProtocol do
  # Client -> Server
  defmodule Plate do
    defstruct [:plate, :timestamp]
  end

  defmodule WantHeartbeat do
    defstruct [:interval]
  end

  defmodule IAmCamera do
    defstruct [:road, :mile, :limit]
  end

  defmodule IAmDispatcher do
    defstruct [:roads]
  end

  # Server -> Client
  defmodule Error do
    defstruct [:message]
  end

  defmodule Ticket do
    defstruct [:plate, :road, :mile1, :timestamp1, :mile2, :timestamp2, :speed]
  end

  defmodule Heartbeat do
    defstruct []
  end

  # protocol implementation

  @error 0x10
  @plate 0x20
  @ticket 0x21
  @want_heartbeat 0x40
  @heartbeat 0x41
  @camera 0x80
  @dispatcher 0x81

  @known_message_types [
    @error,
    @plate,
    @ticket,
    @want_heartbeat,
    @heartbeat,
    @camera,
    @dispatcher
  ]

  # -- decode --
  def decode(packet)

  def decode(
        <<@error, error_message_size::8, message::binary-size(error_message_size), rest::binary>>
      ) do
    {:ok, %Error{message: message}, rest}
  end

  def decode(
        <<@plate, plate_size::8, plate::binary-size(plate_size), timestamp::32, rest::binary>>
      ) do
    message = %Plate{plate: plate, timestamp: timestamp}
    {:ok, message, rest}
  end

  def decode(
        <<@ticket, plate_size::8, plate::binary-size(plate_size), road::16, mile1::16,
          timestamp1::32, mile2::16, timestamp2::32, speed::16, rest::binary>>
      ) do
    message = %Ticket{
      plate: plate,
      road: road,
      mile1: mile1,
      timestamp1: timestamp1,
      mile2: mile2,
      timestamp2: timestamp2,
      speed: speed
    }

    {:ok, message, rest}
  end

  def decode(<<@want_heartbeat, interval::32, rest::binary>>) do
    {:ok, %WantHeartbeat{interval: interval}, rest}
  end

  def decode(<<@heartbeat, rest::binary>>) do
    {:ok, %Heartbeat{}, rest}
  end

  def decode(<<@camera, road::16, mile::16, limit::16, rest::binary>>) do
    {:ok, %IAmCamera{road: road, mile: mile, limit: limit}, rest}
  end

  def decode(<<@dispatcher, roads_count::8, roads::binary-size(roads_count * 2), rest::binary>>) do
    roads = for <<road::16 <- roads>>, do: road
    {:ok, %IAmDispatcher{roads: roads}, rest}
  end

  def decode(<<message_type, _rest::binary>>) when message_type in @known_message_types do
    :partial
  end

  def decode(<<_message_type, _rest::binary>>) do
    :error
  end

  def decode(<<>>), do: :partial

  # -- encode --
  def encode(message)

  def encode(%Error{message: message}) do
    <<@error, byte_size(message), message::binary>>
  end

  def encode(%Plate{} = plate) do
    <<@plate, protocol_string(plate.plate)::binary, plate.timestamp::32>>
  end

  def encode(%Ticket{} = ticket) do
    <<@ticket, protocol_string(ticket.plate)::binary, ticket.road::16, ticket.mile1::16,
      ticket.timestamp1::32, ticket.mile2::16, ticket.timestamp2::32, ticket.speed::16>>
  end

  def encode(%WantHeartbeat{interval: interval}) do
    <<@want_heartbeat, interval::32>>
  end

  def encode(%Heartbeat{}) do
    <<@heartbeat>>
  end

  def encode(%IAmCamera{road: road, mile: mile, limit: limit}) do
    <<@camera, road::16, mile::16, limit::16>>
  end

  def encode(%IAmDispatcher{roads: roads}) do
    <<@dispatcher, protocol_roads(roads)::binary>>
  end

  defp protocol_string(string) do
    <<byte_size(string)::8, string::binary>>
  end

  defp protocol_roads(roads) do
    encoded_roads = IO.iodata_to_binary(for road <- roads, do: <<road::16>>)
    <<length(roads)::8, encoded_roads::binary>>
  end
end
