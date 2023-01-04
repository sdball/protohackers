defmodule Protohackers.IsPrimeServer do
  use GenServer

  require Logger

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(:no_state) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      # receive data as binaries (instead of lists)
      mode: :binary,
      # block on `:gen_tcp.recv/2` until data is available
      active: false,
      # allow reusing the address if the listener crashes
      reuseaddr: true,
      # keep the peer socket open after the client closes its writes
      exit_on_close: false,
      # receive data line by line
      packet: :line
    ]

    case :gen_tcp.listen(11236, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting isPrime server on port 11236")
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn ->
          handle_connection(socket)
        end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  defp handle_connection(socket) do
    with {:ok, json} <- receive_line(socket),
         {:ok, submitted_data} <-
           Jason.decode(json),
         {:ok, number} <-
           validate_request(submitted_data) do
      send_response(socket, number |> is_prime?)
      handle_connection(socket)
    else
      {:error, :closed} ->
        :gen_tcp.close(socket)

      {:error, :timeout} ->
        :gen_tcp.close(socket)

      {:error, %Jason.DecodeError{}} ->
        :gen_tcp.send(socket, "malformed\n")
        :gen_tcp.close(socket)

      {:error, :invalid_request} ->
        :gen_tcp.send(socket, "malformed\n")
        :gen_tcp.close(socket)
    end
  end

  defp receive_line(socket) do
    :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_millis = 10_000)
  end

  defp validate_request(%{"method" => "isPrime", "number" => number}) when is_number(number) do
    {:ok, number}
  end

  defp validate_request(_malformed) do
    {:error, :invalid_request}
  end

  defp send_response(socket, is_prime) do
    response = %{method: "isPrime", prime: is_prime} |> Jason.encode!()
    :gen_tcp.send(socket, "#{response}\n")
  end

  defp is_prime?(number) when is_integer(number) do
    Code.ensure_loaded!(PrimeFactors)
    PrimeFactors.is_prime?(number)
  end

  defp is_prime?(number) when is_float(number), do: false
end
