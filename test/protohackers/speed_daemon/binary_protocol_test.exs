defmodule Protohackers.SpeedDaemon.BinaryProtocolTest do
  use ExUnit.Case, async: true
  alias Protohackers.SpeedDaemon.BinaryProtocol

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

  def encode_decode(message) do
    message
    |> BinaryProtocol.encode()
    |> BinaryProtocol.decode()
  end

  describe "encode/decode" do
    test "Error" do
      message = %BinaryProtocol.Error{message: "some error"}
      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "Plate" do
      message = %BinaryProtocol.Plate{plate: "SO COOL", timestamp: 112_358}
      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "Ticket" do
      message = %BinaryProtocol.Ticket{
        plate: "VY44RHB",
        road: 7399,
        mile1: 6002,
        timestamp1: 287_207,
        mile2: 6012,
        timestamp2: 287_507,
        speed: 12000
      }

      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "WantHeartbeat" do
      message = %BinaryProtocol.WantHeartbeat{interval: 11}
      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "HeartBeat" do
      message = %BinaryProtocol.Heartbeat{}
      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "IAmCamera" do
      message = %BinaryProtocol.IAmCamera{road: 123, mile: 8, limit: 55}
      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "IAmDispatcher" do
      message = %BinaryProtocol.IAmDispatcher{roads: [123, 256]}
      assert {:ok, ^message, ""} = encode_decode(message)
    end

    test "valid partial messages are partial" do
      @known_message_types
      |> Enum.reject(&(&1 == @heartbeat))
      |> Enum.each(fn message_type ->
        assert BinaryProtocol.decode(<<message_type>>) == :partial
      end)
    end

    test "invalid messages are invalid" do
      assert BinaryProtocol.decode(<<0x111>>) == :error
    end
  end
end
