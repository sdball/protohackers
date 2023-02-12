defmodule Protohackers.SpeedDaemon.CentralTicketDispatcher do
  use GenServer

  alias Protohackers.SpeedDaemon.{DispatchersRegistry, BinaryProtocol}

  require Logger

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_args, name: __MODULE__)
  end

  # -- api --

  def add_road(road, speed_limit) do
    GenServer.cast(__MODULE__, {:add_road, road, speed_limit})
  end

  def register_observation(road, mile, plate, timestamp) do
    GenServer.cast(__MODULE__, {:register_observation, road, mile, plate, timestamp})
  end

  # -- state --

  defmodule Road do
    defstruct [:id, :speed_limit, observations: %{}, pending_tickets: []]
  end

  defstruct roads: %{}, sent_tickets_per_day: []

  @impl true
  def init(:no_args) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast(cast, state)

  def handle_cast({:add_road, road_id, speed_limit}, state) do
    Logger.debug(
      "SpeedDaemon.CentralTicketDispatcher.add_road road=#{inspect(road_id)} limit=#{inspect(speed_limit)}"
    )

    new_road = %Road{id: road_id, speed_limit: speed_limit}
    state = update_in(state.roads, &Map.put_new(&1, road_id, new_road))
    {:noreply, state}
  end

  def handle_cast({:register_observation, road_id, mile, plate, timestamp}, state) do
    state =
      update_in(state.roads[road_id].observations[plate], fn observations ->
        observations = observations || []
        [{timestamp, mile}] ++ observations
      end)

    updated_road = generate_tickets(state.roads[road_id], plate)
    state = put_in(state.roads[road_id], updated_road)
    state = dispatch_tickets(state, road_id)
    {:noreply, state}
  end

  @impl true
  def handle_info({:register, DispatchersRegistry, road_id, _partition, _value}, state) do
    state = dispatch_tickets(state, road_id)
    {:noreply, state}
  end

  def handle_info({:unregister, DispatchersRegistry, _dispatcher, _partition}, state) do
    {:noreply, state}
  end

  defp generate_tickets(%Road{} = road, plate) do
    observations =
      road.observations[plate]
      |> Enum.sort_by(fn {timestamp, _mile} -> timestamp end)
      |> Enum.dedup_by(fn {timestamp, _mile} -> timestamp end)

    tickets =
      observations
      |> Stream.zip(Enum.drop(observations, 1))
      |> Enum.flat_map(fn {{ts1, mile1}, {ts2, mile2}} ->
        distance = abs(mile1 - mile2)
        speed_mph = round(distance / (ts2 - ts1) * 3600)

        if speed_mph > road.speed_limit do
          [
            %BinaryProtocol.Ticket{
              plate: plate,
              road: road.id,
              mile1: mile1,
              timestamp1: ts1,
              mile2: mile2,
              timestamp2: ts2,
              speed: speed_mph * 100
            }
          ]
        else
          []
        end
      end)

    %Road{road | pending_tickets: road.pending_tickets ++ tickets}
  end

  def dispatch_tickets(state, road_id) do
    case Map.fetch(state.roads, road_id) do
      {:ok, %Road{} = road} ->
        {tickets_to_dispatch, sent_tickets_per_day} =
          Enum.flat_map_reduce(
            state.roads[road_id].pending_tickets,
            state.sent_tickets_per_day,
            fn ticket, acc ->
              case Registry.lookup(DispatchersRegistry, road.id) do
                [] ->
                  Logger.debug(
                    "SpeedDaemon.CentralTicketDispatcher.no_dispatchers_available road=#{ticket.road}"
                  )

                  {[ticket], acc}

                dispatchers ->
                  ticket_start_day = floor(ticket.timestamp1 / 86_400)
                  ticket_end_day = floor(ticket.timestamp2 / 86_400)

                  if {ticket_start_day, ticket.plate} in acc or
                       {ticket_end_day, ticket.plate} in acc do
                    Logger.debug(
                      "SpeedDaemon.CentralTicketDispatcher.already_ticketed_for_day #{inspect(ticket)}"
                    )

                    {[], acc}
                  else
                    {pid, _} = Enum.random(dispatchers)
                    GenServer.cast(pid, {:dispatch_ticket, ticket})
                    sent = for day <- ticket_start_day..ticket_end_day, do: {day, ticket.plate}
                    {[], acc ++ sent}
                  end
              end
            end
          )

        state = put_in(state.sent_tickets_per_day, sent_tickets_per_day)
        state = put_in(state.roads[road_id].pending_tickets, tickets_to_dispatch)
        state

      :error ->
        state
    end
  end
end
