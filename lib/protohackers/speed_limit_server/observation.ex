defmodule Protohackers.SpeedLimitServer.Observation do
  defstruct [:days, :speed, :limit, :road, :plate, :reading1, :reading2]

  def new() do
    %__MODULE__{}
  end

  def new(reading1, reading2) do
    new()
    |> add_readings(reading1, reading2)
  end

  def add_readings(observation, reading1, reading2) do
    {r1, r2} =
      if reading1.timestamp < reading2.timestamp do
        {reading1, reading2}
      else
        {reading2, reading1}
      end

    %{observation | reading1: r1, reading2: r2, limit: r1.limit, plate: r1.plate, road: r1.road}
    |> calculate_average_speed()
    |> calculate_days_covered()
  end

  def calculate_average_speed(observation = %{reading1: r1, reading2: r2}) do
    distance = (r1.mile - r2.mile) |> abs()
    time = r2.timestamp - r1.timestamp
    mph = calculate_mph(distance, time)
    %{observation | speed: mph}
  end

  def calculate_days_covered(observation = %{reading1: r1, reading2: r2}) do
    %{observation | days: r1.day..r2.day}
  end

  def from_pairs(pairs) do
    pairs
    |> Enum.map(fn {r1, r2} ->
      new(r1, r2)
    end)
  end

  def calculate_mph(distance, time), do: distance / time * 3600
end
