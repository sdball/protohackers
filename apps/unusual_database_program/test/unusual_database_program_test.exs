defmodule UnusualDatabaseProgramTest do
  use ExUnit.Case

  setup_all do
    [port: Application.get_env(:unusual_database_program, :port)]
  end

  test "a client can write and retrieve a key/value", %{port: port} do
    key = "magic word"
    value = "xyzzy"

    {:ok, socket} = :gen_udp.open(0, mode: :binary, active: false)

    # write the key/value
    :gen_udp.send(socket, ~c(localhost), port, Enum.join([key, value], "="))

    # wait for networking
    Process.sleep(50)

    # read the value
    :gen_udp.send(socket, ~c(localhost), port, key)
    {:ok, {_ip, _port, response}} = :gen_udp.recv(socket, 0)
    assert response == "magic word=xyzzy"
  end

  test "extra delimiters are treated as part of the value", %{port: port} do
    key = "hello"
    message = "hello=old=friend"

    {:ok, socket} = :gen_udp.open(0, mode: :binary, active: false)

    # write the key/value
    :gen_udp.send(socket, ~c(localhost), port, message)

    # wait for networking
    Process.sleep(50)

    # read the value
    :gen_udp.send(socket, ~c(localhost), port, key)
    {:ok, {_ip, _port, response}} = :gen_udp.recv(socket, 0)
    assert response == message
  end

  test "an unset key returns nothing", %{port: port} do
    key = "plugh"

    {:ok, socket} = :gen_udp.open(0, mode: :binary, active: false)

    # read the value
    :gen_udp.send(socket, ~c(localhost), port, key)
    {:error, :timeout} = :gen_udp.recv(socket, 0, 100)
  end
end
