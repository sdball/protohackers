defmodule MeansToAnEnd do
  @moduledoc """
  Accept asset prices with timestamps and return queried averages

  https://protohackers.com/problem/2

  To test manually with netcat you can use -n -e to echo raw bytes

  echo -n : do not append newline
  echo -e : handle escape codes e.g. `\x49` to make a hex 0x49 byte

  ```
  $ echo -n -e "\x49\x00\x00\x30\x39\x00\x00\x00\x65" | nc localhost 11237
  INSERT - 12345 - 101
  ```
  """
  use GenServer

  require Logger

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port)
  end

  defstruct [:listen_socket, :supervisor]

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
      exit_on_close: false
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting MeansToAnEnd on port #{port}")
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
        Logger.error("[MeansToAnEnd] Unable to accept connection #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  # -- core ------------------------------------------------------------------
  def insert(history, timestamp, price) do
    Map.put(history, timestamp, price)
  end

  def query(history, mintime, maxtime) when mintime <= maxtime do
    matching =
      for {ts, price} <- history, ts >= mintime and ts <= maxtime do
        price
      end

    count = Enum.count(matching)

    if count > 0 do
      (Enum.sum(matching) / Enum.count(matching))
      |> Float.round()
      |> trunc()
    else
      0
    end
  end

  def query(_history, _mintime, _maxtime), do: 0

  # -- server handling -------------------------------------------------------

  defp handle_connection(socket) do
    track_asset_prices_until_closed(socket, _price_history = %{})
    :gen_tcp.close(socket)
  end

  defp track_asset_prices_until_closed(socket, price_history) do
    with {:ok, bytes} <- :gen_tcp.recv(socket, _bytes_to_read = 9, _timeout_millis = 30_000) do
      log(:info, "BYTES #{inspect(bytes)}")

      new_price_history =
        case bytes do
          <<"I", timestamp::signed-integer-32, price::signed-integer-32>> ->
            log(:info, "INSERT #{timestamp} #{price}")
            insert(price_history, timestamp, price)

          <<"Q", mintime::signed-integer-32, maxtime::signed-integer-32>> ->
            log(:info, "QUERY #{mintime} #{maxtime}")
            average = query(price_history, mintime, maxtime)
            log(:info, "AVERAGE #{average}")
            :gen_tcp.send(socket, <<average::signed-integer-32>>)
            price_history

          _undefined ->
            price_history
        end

      track_asset_prices_until_closed(socket, new_price_history)
    else
      # this is part of the process
      {:error, :closed} ->
        :ok

      # general errors
      error ->
        log(:error, error)
        error
    end
  end

  defp log(:info, message) when is_binary(message) do
    Logger.info("[MeansToAnEnd] [#{inspect(self())}] #{message}")
  end

  defp log(:error, message) when is_binary(message) do
    Logger.error("[MeansToAnEnd] [#{inspect(self())}] #{message}")
  end

  defp log(level, message), do: log(level, inspect(message))
end
