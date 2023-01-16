defmodule Protohackers.SpeedLimitServer.PlateReading do
  defstruct [:plate, :timestamp, :road, :mile, :limit, :day]

  def build(plate, timestamp, road, mile, limit) do
    %__MODULE__{
      plate: plate,
      timestamp: timestamp,
      road: road,
      mile: mile,
      limit: limit,
      day: day(timestamp)
    }
  end

  def day(timestamp), do: floor(timestamp / 86400)
end
