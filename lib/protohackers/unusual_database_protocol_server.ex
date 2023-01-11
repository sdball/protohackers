defmodule Protohackers.UnusualDatabaseProtocolServer do
  @moduledoc """
  UDP-based key/value store implementation

  Since UDP does not provide retransmission of dropped packets clients have
  to be careful not to send requests too fast, and have to accept that some
  requests or responses may be dropped.

  Each request, and each response, is a single UDP packet.

  There are only two types of request: **insert** and **retrieve**. Insert
  allows a client to insert a value for a key, and retrieve allows a client to
  retrieve the value for a key.

  ## Insert

  A request is an insert if it contains an equals sign ("=", or ASCII 61).

  The first equals sign separates the key from the value. This means keys can
  not contain the equals sign. Other than the equals sign, keys can be made up
  of any arbitrary characters. The empty string is a valid key.

  Subsequent equals signs (if any) are included in the value. The value can be
  any arbitrary data, including the empty string.

  For example:

  * `foo=bar` will insert a key `foo` with value `bar`.
  * `foo=bar=baz` will insert a key `foo` with value `bar=baz`.
  * `foo=` will insert a key `foo` with an empty string value.
  * `foo===` will insert a key `foo` with value `==`.
  * `=foo` will insert a key of the empty string with value `foo`.

  If the server receives an insert request for a key that already exists, the
  stored value will be updated to the new value.

  An insert request does not yield a response.

  ## Retrieve

  A request that does not contain an equals sign is a retrieve request.

  In response to a retrieve request, the server will send back the key and its
  corresponding value, separated by an equals sign. Responses will be sent to
  the IP address and port number that the request originated from.

  If a requests is for a key that has been inserted multiple times, the server
  must return the most recent value.

  If a request attempts to retrieve a key for which no value exists, the server
  will not respond.

  ### Example request:

      message

  ### Example response:

      message=Hello,world!
  """

  use GenServer

  require Logger

  def start_link(port \\ 11239) do
    GenServer.start_link(__MODULE__, port)
  end

  defstruct [:open_socket, :supervisor, database: Map.new()]

  @impl true
  def init(port) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    bind_ip =
      if Mix.env() == :prod do
        {:ok, fly_global_services_ip} = :inet.getaddr('fly-global-services', :inet)
        fly_global_services_ip
      else
        {127, 0, 0, 1}
      end

    open_options = [
      mode: :binary,
      ip: bind_ip
    ]

    with {:ok, open_socket} <- :gen_udp.open(port, open_options) do
      Logger.info("Opened port #{port} for UnusualDatabaseProtocol Server on #{inspect(bind_ip)}")
      state = %__MODULE__{open_socket: open_socket, supervisor: supervisor}
      {:ok, state}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:udp, socket, remote_ip, remote_port, message}, state) do
    cond do
      message == "version" ->
        GenServer.cast(self(), {:version, {socket, remote_ip, remote_port}})

      String.contains?(message, "=") ->
        GenServer.cast(self(), {:insert, message})

      true ->
        GenServer.cast(self(), {:retrieve, {socket, remote_ip, remote_port, message}})
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info("[UDP] Elixir message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:insert, message}, state) do
    [key | value] = String.split(message, "=")
    value = Enum.join(value, "=")
    new_database = insert(state.database, key, value)
    Logger.info("[UDP] wrote #{key} / #{value} into the database")
    {:noreply, %{state | database: new_database}}
  end

  def handle_cast({:retrieve, {socket, ip, port, key}}, state) do
    with {:ok, value} <- retrieve(state.database, key) do
      response = key <> "=" <> value
      Logger.info("[UDP] sending #{response} for #{key} to #{inspect(ip)}:#{port}")
      :gen_udp.send(socket, ip, port, response)
    end

    {:noreply, state}
  end

  def handle_cast({:version, {socket, ip, port}}, state) do
    Logger.info("[UDP] sending version response to #{inspect(ip)}:#{port}")
    :gen_udp.send(socket, ip, port, "version=sdball unusual database protocol server v1")
    {:noreply, state}
  end

  def insert(database, key, value) do
    Map.put(database, key, value)
  end

  def retrieve(database, key) do
    case Map.get(database, key) do
      nil -> {:error, :missing}
      value -> {:ok, value}
    end
  end
end
