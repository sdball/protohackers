defmodule Protohackers.SpeedLimitServer.Database do
  use GenServer
  require Logger
  alias Protohackers.SpeedLimitServer.{PlateReading, Observation, Ticket, Client}

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: SpeedLimitServer.Database)
  end

  def plate_reading(plate_reading) do
    GenServer.cast(SpeedLimitServer.Database, {:plate, plate_reading})
  end

  def connect_dispatcher(dispatcher, roads) do
    GenServer.cast(
      SpeedLimitServer.Database,
      {:dispatcher_connect, dispatcher, roads}
    )
  end

  def disconnect_dispatcher(dispatcher) do
    GenServer.cast(
      SpeedLimitServer.Database,
      {:dispatcher_disconnect, dispatcher}
    )
  end

  # plate_readings : road => readings
  # tickets : road => tickets
  # dispatchers : road => dispatchers
  # tickets_index : MapSet : {day, plate}
  defstruct plate_readings: Map.new(),
            tickets: Map.new(),
            dispatchers: Map.new(),
            tickets_index: MapSet.new()

  @impl true
  def init(:ok) do
    database = %__MODULE__{}
    {:ok, database}
  end

  @impl true
  def handle_cast({:plate, reading = %PlateReading{}}, database) do
    new_database =
      database
      |> maybe_ticket(reading)
      |> add_plate_reading(reading)

    {:noreply, new_database}
  end

  @impl true
  def handle_cast({:dispatcher_connect, dispatcher, roads}, database) do
    new_database =
      database
      |> add_dispatcher(dispatcher, roads)

    {:noreply, new_database, {:continue, {:new_dispatcher, roads}}}
  end

  def handle_cast({:dispatcher_disconnect, dispatcher}, database) do
    new_database =
      database
      |> remove_dispatcher(dispatcher)

    {:noreply, new_database}
  end

  @impl true
  def handle_continue({:new_dispatcher, roads}, database) do
    tickets_update =
      for road <- roads, ticket <- tickets_for_road(database, road), reduce: %{} do
        acc ->
          ticket =
            if ticket.submitted do
              ticket
            else
              dispatcher = random_dispatcher(database, road)
              Client.send_ticket(dispatcher, ticket)
              %{ticket | submitted: true}
            end

          Map.update(acc, road, [ticket], fn tickets ->
            [ticket | tickets]
          end)
      end

    new_tickets = Map.merge(database.tickets, tickets_update)

    {:noreply, %{database | tickets: new_tickets}}
  end

  def remove_dispatcher(database, dispatcher) do
    new_dispatchers =
      for {road, dispatchers} <- database.dispatchers, reduce: %{} do
        acc ->
          Map.put(acc, road, dispatchers |> Enum.reject(&(&1 == dispatcher)))
      end

    %{database | dispatchers: new_dispatchers}
  end

  def tickets_for_road(database, road) do
    Map.get(database.tickets, road, [])
  end

  def random_dispatcher(database, road) do
    case Map.get(database.dispatchers, road) do
      nil ->
        nil

      [] ->
        nil

      dispatchers ->
        Enum.random(dispatchers)
    end
  end

  def add_dispatcher(database, dispatcher, roads) do
    Logger.info(
      "SLS.Database.add_dispatcher dispatcher=#{inspect(dispatcher)} roads=#{inspect(roads)}"
    )

    new_dispatchers =
      for road <- roads, reduce: database.dispatchers do
        acc ->
          Map.update(acc, road, [dispatcher], fn dispatchers ->
            [dispatcher | dispatchers]
          end)
      end

    %{database | dispatchers: new_dispatchers}
  end

  def add_plate_reading(database, reading) do
    %{
      database
      | plate_readings:
          Map.update(database.plate_readings, reading.road, [reading], fn readings ->
            [reading | readings]
          end)
    }
  end

  def maybe_ticket(database, reading) do
    if already_ticketed_for_the_day?(database, reading) do
      Logger.info(
        "SLS.Database.already_ticketed plate=#{inspect(reading.plate)} day=#{reading.day}"
      )

      database
    else
      find_surrounding_pairs(database, reading)
      |> build_observations()
      |> reject_within_limit()
      |> reject_already_ticketed_days(database)
      |> sort_by_number_of_days_covered(:asc)
      |> List.first()
      |> case do
        nil ->
          database

        violation ->
          create_ticket(database, violation)
      end
    end
  end

  def build_observations(pairs) do
    Observation.from_pairs(pairs)
  end

  def create_ticket(database, violation) do
    Logger.info("SLS.Database.create_ticket violation=#{inspect(violation)}")
    ticket = Ticket.from_violation(violation)

    dispatcher = random_dispatcher(database, violation.road)

    ticket =
      if dispatcher do
        Client.send_ticket(dispatcher, ticket)
        %{ticket | submitted: true}
      else
        ticket
      end

    new_tickets =
      Map.update(database.tickets, ticket.road, [ticket], fn road_tickets ->
        [ticket | road_tickets]
      end)

    new_tickets_index =
      for day <- violation.days, reduce: database.tickets_index do
        acc -> MapSet.put(acc, {day, violation.plate})
      end

    %{database | tickets: new_tickets, tickets_index: new_tickets_index}
  end

  def sort_by_number_of_days_covered(observations, order) do
    observations
    |> Enum.sort_by(
      fn %{days: days} ->
        Enum.count(days)
      end,
      order
    )
  end

  def reject_already_ticketed_days(observations, database) do
    Enum.reject(observations, fn %{days: days, plate: plate} ->
      days
      |> Enum.to_list()
      |> Enum.any?(fn day ->
        already_ticketed_for_the_day?(database, %{plate: plate, day: day})
      end)
    end)
  end

  def already_ticketed_for_the_day?(database, %{plate: plate, day: day}) do
    MapSet.member?(database.tickets_index, {day, plate})
  end

  def find_surrounding_pairs(database, reading) do
    sorted_readings =
      sorted_readings_for_road_and_plate(
        database.plate_readings,
        reading.road,
        reading.plate
      )

    previous = find_previous_reading(sorted_readings, reading.timestamp)
    following = find_following_reading(sorted_readings, reading.timestamp)

    case {previous, following} do
      {nil, nil} -> []
      {nil, following} -> [{reading, following}]
      {previous, nil} -> [{previous, reading}]
      {previous, following} -> [{previous, reading}, {reading, following}]
    end
  end

  def sorted_readings_for_road_and_plate(plate_readings, road, plate) do
    plate_readings
    |> for_road(road)
    |> filter_plate(plate)
    |> sort_by_timestamp()
  end

  def for_road(readings, road) when is_map(readings) do
    readings |> Map.get(road, [])
  end

  def filter_plate(readings, plate) when is_list(readings) do
    readings
    |> Enum.filter(&(&1.plate == plate))
  end

  def sort_by_timestamp(readings) do
    Enum.sort_by(readings, & &1.timestamp)
  end

  def find_previous_reading(readings, timestamp) do
    readings
    |> Enum.filter(&(&1.timestamp < timestamp))
    |> List.last()
  end

  def find_following_reading(readings, timestamp) do
    readings
    |> Enum.filter(&(&1.timestamp > timestamp))
    |> List.first()
  end

  def reject_within_limit(observations) do
    observations
    |> Enum.filter(fn observation ->
      observation.speed > observation.limit
    end)
  end
end
