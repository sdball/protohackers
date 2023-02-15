defmodule SmokeTestTest do
  use ExUnit.Case, async: true

  def connect() do
    port = Application.get_env(:smoke_test, :port)
    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    socket
  end

  test "sends back all given bytes" do
    sent_data = "some data"
    socket = connect()
    :gen_tcp.send(socket, sent_data)
    :gen_tcp.shutdown(socket, :write)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    assert response == sent_data
  end

  test "sends back all given bytes from multiple sends" do
    socket = connect()
    :gen_tcp.send(socket, "abcde")
    :gen_tcp.send(socket, "12345")
    :gen_tcp.send(socket, "xyzzy")
    :gen_tcp.shutdown(socket, :write)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    assert response == "abcde12345xyzzy"
  end

  test "writes past the limit are rejected" do
    socket = connect()
    :gen_tcp.send(socket, String.duplicate("A", 1024 * 101))
    :gen_tcp.shutdown(socket, :write)
    assert {:ok, "ERR_EXCEEDED_WRITE_LIMIT"} = :gen_tcp.recv(socket, 0)
  end

  test "concurrent connections are concurrent" do
    socket1 = connect()
    socket2 = connect()

    :gen_tcp.send(socket1, "abcde")
    :gen_tcp.send(socket2, "12345")

    :gen_tcp.shutdown(socket2, :write)
    {:ok, "12345"} = :gen_tcp.recv(socket2, 0)

    :gen_tcp.shutdown(socket1, :write)
    {:ok, "abcde"} = :gen_tcp.recv(socket1, 0)
  end
end
