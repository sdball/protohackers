defmodule Protohackers.EchoServerTest do
  use ExUnit.Case, async: true

  test "sends back all given bytes" do
    sent_data = "some data"
    {:ok, socket} = :gen_tcp.connect('localhost', 11235, [:binary, active: false])
    :gen_tcp.send(socket, sent_data)
    :gen_tcp.shutdown(socket, :write)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    assert response == sent_data
  end

  test "sends back all given bytes from multiple sends" do
    {:ok, socket} = :gen_tcp.connect('localhost', 11235, [:binary, active: false])
    :gen_tcp.send(socket, "abcde")
    :gen_tcp.send(socket, "12345")
    :gen_tcp.send(socket, "xyzzy")
    :gen_tcp.shutdown(socket, :write)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    assert response == "abcde12345xyzzy"
  end

  test "writes past the limit are rejected" do
    {:ok, socket} = :gen_tcp.connect('localhost', 11235, [:binary, active: false])
    :gen_tcp.send(socket, String.duplicate("A", 1024 * 101))
    :gen_tcp.shutdown(socket, :write)
    assert {:ok, "ERR_EXCEEDED_WRITE_LIMIT"} = :gen_tcp.recv(socket, 0)
  end

  test "concurrent connections are concurrent" do
    {:ok, socket1} = :gen_tcp.connect('localhost', 11235, [:binary, active: false])
    {:ok, socket2} = :gen_tcp.connect('localhost', 11235, [:binary, active: false])

    :gen_tcp.send(socket1, "abcde")
    :gen_tcp.send(socket2, "12345")

    :gen_tcp.shutdown(socket2, :write)
    {:ok, "12345"} = :gen_tcp.recv(socket2, 0)

    :gen_tcp.shutdown(socket1, :write)
    {:ok, "abcde"} = :gen_tcp.recv(socket1, 0)
  end
end
