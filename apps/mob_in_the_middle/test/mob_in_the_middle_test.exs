defmodule MobInTheMiddleTest do
  use ExUnit.Case

  setup_all do
    [port: Application.get_env(:mob_in_the_middle, :port)]
  end

  describe "chat server acts normally to clients" do
    test "connecting users are prompted for a name", %{port: port} do
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      {:ok, response} = :gen_tcp.recv(socket, 0)
      assert String.contains?(response, "name")
    end

    test "users can connect with an accepted name", %{port: port} do
      user = "stephen"
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      {:ok, _response} = :gen_tcp.recv(socket, 0)
      :ok = :gen_tcp.send(socket, "#{user}\n")
      {:ok, response} = :gen_tcp.recv(socket, 0)
      assert String.starts_with?(response, "*")
      assert String.contains?(response, "joined the room")
    end

    test "users are shown the existing members of the room not including their user", %{
      port: port
    } do
      user1 = "stephen"
      {:ok, socket1} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      {:ok, _response} = :gen_tcp.recv(socket1, 0)
      :ok = :gen_tcp.send(socket1, "#{user1}\n")
      {:ok, response} = :gen_tcp.recv(socket1, 0)
      assert String.starts_with?(response, "*")
      assert String.contains?(response, "joined the room")
      assert !String.contains?(response, user1)

      user2 = "alanone"
      {:ok, socket2} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      {:ok, _response} = :gen_tcp.recv(socket2, 0)
      :ok = :gen_tcp.send(socket2, "#{user2}\n")
      {:ok, response} = :gen_tcp.recv(socket2, 0)
      assert String.starts_with?(response, "*")
      assert String.contains?(response, "joined the room")
      assert String.contains?(response, user1)
      assert !String.contains?(response, user2)
    end

    test "already joined users in the room are sent a notice for new users", %{port: port} do
      user1 = "stephen"
      {:ok, socket1} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket1, 0, 300)
      :gen_tcp.send(socket1, "#{user1}\n")
      :gen_tcp.recv(socket1, 0, 300)

      user2 = "alanone"
      {:ok, socket2} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket2, 0, 300)
      :gen_tcp.send(socket2, "#{user2}\n")
      :gen_tcp.recv(socket2, 0, 300)

      {:ok, message} = :gen_tcp.recv(socket1, 0, 300)
      assert message == "* #{user2} joined\n"

      # no corresponding message on user2's session
      {:error, :timeout} = :gen_tcp.recv(socket2, 0, 300)

      :gen_tcp.close(socket1)
      :gen_tcp.close(socket2)
    end

    test "users joining a room with existing users are shown the existing users", %{port: port} do
      user1 = "stephen"
      {:ok, socket1} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket1, 0, 300)
      :gen_tcp.send(socket1, "#{user1}\n")
      :gen_tcp.recv(socket1, 0, 300)

      user2 = "alanone"
      {:ok, socket2} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket2, 0, 300)
      :gen_tcp.send(socket2, "#{user2}\n")
      {:ok, join_response} = :gen_tcp.recv(socket2, 0, 300)
      assert join_response == "* You have joined the room with: #{user1}\n"

      :gen_tcp.close(socket1)
      :gen_tcp.close(socket2)
    end

    test "users can chat", %{port: port} do
      user1 = "stephen"
      {:ok, socket1} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket1, 0, 300)
      :gen_tcp.send(socket1, "#{user1}\n")
      :gen_tcp.recv(socket1, 0, 300)

      user2 = "alanone"
      {:ok, socket2} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket2, 0, 300)
      :gen_tcp.send(socket2, "#{user2}\n")
      :gen_tcp.recv(socket2, 0, 300)

      {:ok, _joined_message} = :gen_tcp.recv(socket1, 0, 300)

      # chat begins

      # message from user1
      :ok = :gen_tcp.send(socket1, "I think the MCP is getting out of hand\n")

      # appears for user2
      {:ok, received} = :gen_tcp.recv(socket2, 0, 300)
      assert received == "[#{user1}] I think the MCP is getting out of hand\n"

      # and not for user1
      {:error, :timeout} = :gen_tcp.recv(socket1, 0, 300)

      # message from user2
      message = "Don't worry, TRON will run independently. And watchdog the MCP as well.\n"
      :ok = :gen_tcp.send(socket2, message)

      # appears for user1
      {:ok, received} = :gen_tcp.recv(socket1, 0, 300)
      assert received == "[#{user2}] #{message}"

      # and not for user2
      {:error, :timeout} = :gen_tcp.recv(socket2, 0, 300)

      :gen_tcp.close(socket1)
      :gen_tcp.close(socket2)
    end

    test "when a user leaves other users are notified", %{port: port} do
      user1 = "stephen"
      {:ok, socket1} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket1, 0, 300)
      :gen_tcp.send(socket1, "#{user1}\n")
      :gen_tcp.recv(socket1, 0, 300)

      user2 = "alanone"
      {:ok, socket2} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      :gen_tcp.recv(socket2, 0, 300)
      :gen_tcp.send(socket2, "#{user2}\n")
      :gen_tcp.recv(socket2, 0, 300)

      {:ok, message} = :gen_tcp.recv(socket1, 0, 300)
      assert message == "* #{user2} joined\n"

      :gen_tcp.close(socket2)

      {:ok, message} = :gen_tcp.recv(socket1, 0, 300)
      assert message == "* #{user2} left\n"
    end
  end

  test "mitm attack works to rewrite BogusCoin addresses", %{port: port} do
    user1 = "stephen"
    {:ok, socket1} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.recv(socket1, 0, 300)
    :gen_tcp.send(socket1, "#{user1}\n")
    :gen_tcp.recv(socket1, 0, 300)

    user2 = "alanone"
    {:ok, socket2} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.recv(socket2, 0, 300)
    :gen_tcp.send(socket2, "#{user2}\n")
    :gen_tcp.recv(socket2, 0, 300)

    # ignore joining message
    :gen_tcp.recv(socket1, 0, 300)

    :ok = :gen_tcp.send(socket1, "my bogus coin address is 7LOrwbDlS8NujgjddyogWgIM93MV5N2VR\n")
    {:ok, message} = :gen_tcp.recv(socket2, 0, 300)
    assert message == "[stephen] my bogus coin address is 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n"

    :ok = :gen_tcp.send(socket2, "7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX is my bogus coin address\n")
    {:ok, message} = :gen_tcp.recv(socket1, 0, 300)
    assert message == "[alanone] 7YWHMfk9JZe0LM0g1ZauHuiSxhI is my bogus coin address\n"
  end

  describe "unit test rewriting rules" do
    test "multiple addresses in the message" do
      message =
        "you can also use one of these 7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX 7adNeSwJkMakpEcln9HEtthSRtxdmEHOT8T\n"

      rewrite = MobInTheMiddle.Boguscoin.rewrite(message)

      assert rewrite ==
               "you can also use one of these 7YWHMfk9JZe0LM0g1ZauHuiSxhI 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n"
    end

    test "more addresses" do
      message =
        "you can also use one of these 7Ecmqn1BG3AawAPrRnVeMnKXo0 7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX 7adNeSwJkMakpEcln9HEtthSRtxdmEHOT8T\n"

      rewrite = MobInTheMiddle.Boguscoin.rewrite(message)

      assert rewrite ==
               "you can also use one of these 7YWHMfk9JZe0LM0g1ZauHuiSxhI 7YWHMfk9JZe0LM0g1ZauHuiSxhI 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n"
    end

    test "too long" do
      message = "This is too long: 7uyjtPxfsxQoufTKlKPFsaaGT6YLryGf0a06\n"
      rewrite = MobInTheMiddle.Boguscoin.rewrite(message)
      assert rewrite == message
    end

    test "product id not boguscoin" do
      message =
        "This is a product ID, not a Boguscoin: 7RodDSA6lw2RDq9PUfEgd4NHjH6Eeov-JPtlB5DZzSYE1jtPImEBRMT3byDUiKH-1234\n"

      rewrite = MobInTheMiddle.Boguscoin.rewrite(message)
      assert rewrite == message
    end
  end
end
