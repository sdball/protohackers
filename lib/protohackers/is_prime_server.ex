defmodule Protohackers.IsPrimeServer do
  use GenServer

  require Logger

  def start_link(port \\ 11236) do
    GenServer.start_link(__MODULE__, port)
  end

  defstruct [:listen_socket, :supervisor, task_id: 1]

  @impl true
  def init(port) do
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
      # automatically split inputs by newline
      packet: :line
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting isPrime server on port #{port}")
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
        Logger.info("Starting Task.Supervisor child to handle connection #{state.task_id}")

        Task.Supervisor.start_child(state.supervisor, fn ->
          handle_connection(socket, state.task_id)
        end)

        {:noreply, %{state | task_id: state.task_id + 1}, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  def is_prime?(0), do: false

  def is_prime?(number) when is_integer(number) and number > 0 do
    PrimeNumbers.is_prime?(number)
  end

  def is_prime?(number) when is_integer(number) and number < 0 do
    false
  end

  def is_prime?(number) when is_float(number), do: false

  defp handle_connection(socket, task_id) do
    with {:ok, received} <- receive_lines(socket, _buffer = "") do
      case process_lines(socket, task_id, received) do
        {:ok} ->
          handle_connection(socket, task_id)

        {:halt, :malformed} ->
          Logger.error("task_id=#{task_id} : halting malformed")
      end
    else
      {:error, :closed} ->
        Logger.info("task_id=#{task_id} : socket closed")
        :gen_tcp.close(socket)

      {:error, :timeout} ->
        Logger.info("task_id=#{task_id} : socket timeout")
        :gen_tcp.close(socket)

      {:error, :exceeded_write_limit} ->
        Logger.error("task_id=#{task_id} : exceeded write limit")
        :gen_tcp.send(socket, "ERR_EXCEEDED_WRITE_LIMIT")
        :gen_tcp.close(socket)

      {:error, :enotconn} ->
        Logger.error("task_id=#{task_id} : socket not connected")
        :gen_tcp.close(socket)

      _error ->
        Logger.error("task_id=#{task_id} : unknown error")
        :gen_tcp.close(socket)
    end
  end

  defp process_lines(socket, task_id, received) do
    data = IO.iodata_to_binary(received)
    requests = String.split(data, "\n", trim: true)
    parsed = Enum.map(requests, &parse_request(&1, task_id))

    numbers =
      Enum.take_while(parsed, fn
        number when is_number(number) -> true
        _ -> false
      end)

    numbers
    |> Enum.each(fn number ->
      prime? = is_prime?(number)
      Logger.info("task_id=#{task_id} : response : #{number} prime? #{prime?}")
      send_response(socket, prime?)
    end)

    # we've encountered a bad request: stop the works
    if Enum.count(numbers) < Enum.count(requests) do
      Logger.error("task_id=#{task_id} : invalid request detected")
      :gen_tcp.send(socket, "malformed")
      :gen_tcp.close(socket)
      {:halt, :malformed}
    else
      {:ok}
    end
  end

  @buffer_size_limit _100_kb = 1024 * 100

  defp receive_lines(socket, buffer) do
    buffered_size = IO.iodata_length(buffer)

    case :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_millis = 30_000) do
      {:ok, data} when buffered_size + byte_size(data) > @buffer_size_limit ->
        {:error, :exceeded_write_limit}

      {:ok, data} ->
        dbg(data)

        if String.ends_with?(data, "\n") do
          {:ok, [buffer, data]}
        else
          receive_lines(socket, [buffer, data])
        end

      {:error, :closed} ->
        {:ok, buffer}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_request(request, task_id) do
    case Jason.decode(request) do
      {:ok, decoded} ->
        parse_decoded(decoded, task_id)

      {:error, %Jason.DecodeError{}} ->
        Logger.error("task_id=#{task_id} : invalid request : #{inspect(request)}")
        false
    end
  end

  defp parse_decoded(%{"method" => "isPrime", "number" => number}, _task_id)
       when is_number(number) do
    number
  end

  defp parse_decoded(invalid_json, task_id) do
    Logger.error("task_id=#{task_id} : invalid json: #{inspect(invalid_json)}")
    nil
  end

  defp send_response(socket, is_prime) do
    response = %{method: "isPrime", prime: is_prime} |> Jason.encode!()
    :gen_tcp.send(socket, "#{response}\n")
  end
end
