defmodule Protohackers.IsPrimeServerTest do
  alias Protohackers.IsPrimeServer
  use ExUnit.Case

  test "server prime number calculation requirements" do
    assert IsPrimeServer.is_prime?(-4) == false
    assert IsPrimeServer.is_prime?(-3) == false
    assert IsPrimeServer.is_prime?(-2) == false
    assert IsPrimeServer.is_prime?(-1) == false
    assert IsPrimeServer.is_prime?(0) == false
    assert IsPrimeServer.is_prime?(1) == false
    assert IsPrimeServer.is_prime?(2) == true
    assert IsPrimeServer.is_prime?(3) == true
    assert IsPrimeServer.is_prime?(4) == false
  end

  test "rejects malformed request" do
    socket = tcp_connect()
    assert tcp_roundtrip(socket, "not a valid request") == "malformed"
    tcp_close(socket)
  end

  test "rejects invalid request" do
    socket = tcp_connect()
    request = %{method: "notValid", number: 123}
    assert tcp_roundtrip(socket, request |> Jason.encode!()) == "malformed"
    tcp_close(socket)
  end

  test "accepts and answers proper requests" do
    socket = tcp_connect()

    response = tcp_roundtrip(socket, request_prime(2))
    assert response.method == "isPrime"
    assert response.prime == true

    response = tcp_roundtrip(socket, request_prime(5))
    assert response.method == "isPrime"
    assert response.prime == true

    response = tcp_roundtrip(socket, request_prime(6))
    assert response.method == "isPrime"
    assert response.prime == false

    tcp_close(socket)
  end

  test "a valid request can be multiple sends" do
    socket = tcp_connect()
    :gen_tcp.send(socket, "{\"method\":\"isPrime\"")
    :gen_tcp.send(socket, ",\"number\":123}")
    :gen_tcp.send(socket, [10])
    response = tcp_response(socket)
    assert response.method == "isPrime"
    assert response.prime == false
  end

  test "multiple requests are answered in order" do
    socket = tcp_connect()

    request1 = %{method: "isPrime", number: 2} |> Jason.encode!()
    tcp_send(socket, request1)

    request2 = %{method: "isPrime", number: 6} |> Jason.encode!()
    tcp_send(socket, request2)

    [response1, response2] =
      tcp_response(socket)
      |> String.split("\n", trim: true)
      |> Enum.map(&handle_response/1)

    assert response1.method == "isPrime"
    assert response1.prime == true

    assert response2.method == "isPrime"
    assert response2.prime == false

    tcp_close(socket)
  end

  test "multiple requests are answered in order and stop at the first malformed request" do
    socket = tcp_connect()

    request1 = %{method: "isPrime", number: 2} |> Jason.encode!()
    tcp_send(socket, request1)

    request2 = %{method: "isPrime", number: 6} |> Jason.encode!()
    tcp_send(socket, request2)

    request3 = %{method: "isNotValid", number: 6} |> Jason.encode!()
    tcp_send(socket, request3)

    request4 = %{method: "isPrime", number: 7} |> Jason.encode!()
    tcp_send(socket, request4)

    responses = tcp_response(socket) |> String.split("\n", trim: true)
    assert Enum.count(responses) == 3

    [response1, response2, response3] =
      responses
      |> Enum.map(&handle_response/1)

    assert response1.method == "isPrime"
    assert response1.prime == true

    assert response2.method == "isPrime"
    assert response2.prime == false

    assert response3 == "malformed"

    tcp_close(socket)
  end

  test "concurrent connections are concurrent" do
    socket1 = tcp_connect()
    socket2 = tcp_connect()

    request = %{method: "isPrime", number: 47} |> Jason.encode!()

    socket1_response = tcp_roundtrip(socket1, request)
    assert socket1_response.prime == true

    socket2_response = tcp_roundtrip(socket2, request)
    assert socket2_response.prime == true

    socket1_response = tcp_roundtrip(socket1, request)
    assert socket1_response.prime == true

    tcp_close(socket1)
    tcp_close(socket2)
  end

  ## helpers

  def tcp_connect() do
    {:ok, socket} = :gen_tcp.connect('localhost', 11236, [:binary, active: false])
    socket
  end

  def tcp_send(socket, data) do
    data =
      if String.ends_with?(data, "\n") do
        data
      else
        data <> "\n"
      end

    :ok = :gen_tcp.send(socket, data |> String.to_charlist())
    socket
  end

  def tcp_roundtrip(socket, data) do
    socket
    |> tcp_send(data)
    |> tcp_response()
  end

  def tcp_response(socket) do
    # give the server enough time to send
    Process.sleep(50)

    with {:ok, response} <- :gen_tcp.recv(socket, 0) do
      response
      |> handle_response()
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_response(response) do
    with {:ok, data} <- Jason.decode(response, keys: :atoms) do
      data
    else
      _ ->
        response
    end
  end

  def tcp_close(socket) do
    :gen_tcp.close(socket)
  end

  def request_prime(number) do
    %{method: "isPrime", number: number} |> Jason.encode!()
  end
end
