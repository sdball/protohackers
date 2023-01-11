defmodule Protohackers.UnusualDatabaseProtocolServerTest do
  use ExUnit.Case

  test "a client can write and retrieve a key/value" do
    key = "magic word"
    value = "xyzzy"

    {:ok, socket} = :gen_udp.open(11240, mode: :binary, active: false)

    # write the key/value
    :gen_udp.send(socket, ~c(localhost), 11239, Enum.join([key, value], "="))

    # wait for networking
    Process.sleep(50)

    # read the value
    :gen_udp.send(socket, ~c(localhost), 11239, key)
    {:ok, {_ip, _port, response}} = :gen_udp.recv(socket, 0)
    assert response == "magic word=xyzzy"
  end

  test "extra delimiters are treated as part of the value" do
    key = "hello"
    message = "hello=old=friend"

    {:ok, socket} = :gen_udp.open(11240, mode: :binary, active: false)

    # write the key/value
    :gen_udp.send(socket, ~c(localhost), 11239, message)

    # wait for networking
    Process.sleep(50)

    # read the value
    :gen_udp.send(socket, ~c(localhost), 11239, key)
    {:ok, {_ip, _port, response}} = :gen_udp.recv(socket, 0)
    assert response == message
  end

  test "an unset key returns nothing" do
    key = "plugh"

    {:ok, socket} = :gen_udp.open(11240, mode: :binary, active: false)

    # read the value
    :gen_udp.send(socket, ~c(localhost), 11239, key)
    {:error, :timeout} = :gen_udp.recv(socket, 0, 100)
  end
end
