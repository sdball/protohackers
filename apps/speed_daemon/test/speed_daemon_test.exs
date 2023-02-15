defmodule SpeedDaemonTest do
  use ExUnit.Case

  def camera(road: road, mile: mile, limit: limit) do
    <<0x80, road::16, mile::16, limit::16>>
  end

  def dispatcher(roads: roads) do
    roads_binary =
      for road <- roads, reduce: <<>> do
        acc -> acc <> <<road::16>>
      end

    <<0x81, Enum.count(roads)::8, roads_binary::binary>>
  end

  def plate_reading(plate, timestamp: timestamp) do
    <<0x20, byte_size(plate)::8, plate::binary, timestamp::32>>
  end

  def heartbeat(millis: ms) do
    deciseconds = (ms / 100) |> trunc
    <<0x40, deciseconds::32>>
  end

  describe "integration tests" do
    test "example from docs" do
      # camera at mile 8
      {:ok, client1} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(client1, camera(road: 123, mile: 8, limit: 60))

      # plate observed at mile 8
      :gen_tcp.send(client1, plate_reading("UN1X", timestamp: 0))

      # camera at mile 9
      {:ok, client2} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(client2, camera(road: 123, mile: 9, limit: 60))

      # plate observed at mile 9
      :gen_tcp.send(client2, plate_reading("UN1X", timestamp: 45))

      # dispatcher for road 123
      {:ok, dispatcher} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(dispatcher, dispatcher(roads: [123]))

      {:ok, response} = :gen_tcp.recv(dispatcher, 0, 5000)

      # ticket with correct info sent to dispatcher
      # Ticket{plate: "UN1X", road: 123, mile1: 8, timestamp1: 0, mile2: 9, timestamp2: 45, speed: 8000}
      assert response ==
               <<0x21, 0x04, 0x55, 0x4E, 0x31, 0x58, 0x00, 0x7B, 0x00, 0x08, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x09, 0x00, 0x00, 0x00, 0x2D, 0x1F, 0x40>>
    end

    test "client heartbeat requests" do
      {:ok, client} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(client, heartbeat(millis: 100))

      # got a heartbeat
      {:ok, response} = :gen_tcp.recv(client, 0, 500)
      assert response == <<0x41>>

      # got a heartbeat
      {:ok, response} = :gen_tcp.recv(client, 0, 500)
      assert response == <<0x41>>

      # cancel heartbeats
      :gen_tcp.send(client, heartbeat(millis: 0))
      assert {:error, :timeout} == :gen_tcp.recv(client, 0, 500)
    end

    test "a single car" do
      # road=7399 mile=6002 limit=100
      msg_camera1 =
        <<128, 28, 231, 23, 114, 0, 100, 32, 7, 86, 89, 52, 52, 82, 72, 66, 0, 4, 97, 231>>

      # plate="VY44RHB" timestamp=287207
      msg_plate1 = <<32, 7, 86, 89, 52, 52, 82, 72, 66, 0, 4, 97, 231>>

      # road=7399 mile=6012 limit=100
      msg_camera2 =
        <<128, 28, 231, 23, 124, 0, 100, 32, 7, 86, 89, 52, 52, 82, 72, 66, 0, 4, 99, 19>>

      # plate="VY44RHB" timestamp=287507
      msg_plate2 = <<32, 7, 86, 89, 52, 52, 82, 72, 66, 0, 4, 99, 19>>

      # dispatcher roads=[7399]
      msg_dispatcher = <<129, 1, 28, 231>>

      {:ok, camera1} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(camera1, msg_camera1)
      :gen_tcp.send(camera1, msg_plate1)

      {:ok, camera2} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(camera2, msg_camera2)
      :gen_tcp.send(camera2, msg_plate2)

      {:ok, dispatcher} = :gen_tcp.connect('localhost', 11241, mode: :binary, active: false)
      :gen_tcp.send(dispatcher, msg_dispatcher)

      {:ok, response} = :gen_tcp.recv(dispatcher, 0, 5000)

      # ticket= plate: "VY44RHB", road: 7399, mile1: 6002, timestamp1: 287207, mile2: 6012, timestamp2: 287507, speed: 12000
      assert response ==
               <<33, 7, 86, 89, 52, 52, 82, 72, 66, 28, 231, 23, 114, 0, 4, 97, 231, 23, 124, 0,
                 4, 99, 19, 46, 224>>
    end
  end
end
