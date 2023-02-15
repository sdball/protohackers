defmodule BudgetChatTest do
  use ExUnit.Case

  setup_all do
    [port: Application.get_env(:budget_chat, :port)]
  end

  describe "integration" do
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

  describe "unit" do
    test "alphanumeric names are accepted" do
      accepted = ~w(someone word123 SOMEONE SomeOne a b c some0ne)

      Enum.all?(accepted, fn name ->
        {:ok, ^name} = BudgetChat.check_name_format(name)
      end)
    end

    test "non-alphanumeric names are rejected" do
      rejected = [
        "someone!",
        "hello there",
        "@someone"
      ]

      Enum.all?(rejected, fn name ->
        {:error, :rejected_name} = BudgetChat.check_name_format(name)
      end)
    end
  end
end
