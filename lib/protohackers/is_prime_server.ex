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
        Logger.info("Starting IsPrimeServer on port #{port}")
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
          handle_connection(socket, state.task_id)
        end)

        new_task_id = rem(state.task_id + 1, 1000)

        {:noreply, %{state | task_id: new_task_id}, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("[IsPrimeServer] Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  # -- core prime handling functionality for this server ---------------------

  def is_prime?(number) when is_float(number), do: false
  def is_prime?(number) when is_number(number) and number <= 0, do: false

  def is_prime?(number) when is_integer(number) and number > 0 do
    PrimeNumbers.is_prime?(number)
  end

  # -- helpers ---------------------------------------------------------------

  defp handle_connection(socket, task_id) do
    respond_to_lines_until_closed(socket, task_id)
    :gen_tcp.close(socket)
  end

  defp respond_to_lines_until_closed(socket, task_id) do
    with {:ok, line} <- :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_millis = 30_000),
         {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) <-
           Jason.decode(line) do
      prime? = is_prime?(number)
      Logger.info("[IsPrimeServer] task_id=#{task_id} : response : #{number} prime? #{prime?}")
      send_response(socket, prime?)
      respond_to_lines_until_closed(socket, task_id)
    else
      # Jason decoded, but the decoded request is invalid
      {:ok, decoded} ->
        Logger.error("[IsPrimeServer] task_id=#{task_id} : invalid request : #{inspect(decoded)}")
        send_malformed(socket)

      # Jason could not decode json
      {:error, error = %Jason.DecodeError{}} ->
        Logger.error("[IsPrimeServer] task_id=#{task_id} : #{inspect(error)}")
        send_malformed(socket)

      # this is part of the process
      {:error, :closed} ->
        :ok

      # general errors
      error ->
        Logger.error("[IsPrimeServer] task_id=#{task_id} : #{inspect(error)}")
        error
    end
  end

  defp send_response(socket, is_prime) do
    response = %{method: "isPrime", prime: is_prime} |> Jason.encode!()
    :gen_tcp.send(socket, "#{response}\n")
  end

  defp send_malformed(socket) do
    :gen_tcp.send(socket, "malformed")
  end
end
