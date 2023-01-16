defmodule Protohackers.SpeedLimitServer.Ticket do
  defstruct [:plate, :road, :mile1, :timestamp1, :mile2, :timestamp2, :speed, submitted: false]

  def new() do
    %__MODULE__{}
  end

  def from_violation(violation) do
    %__MODULE__{
      plate: violation.plate,
      road: violation.road,
      mile1: violation.reading1.mile,
      timestamp1: violation.reading1.timestamp,
      mile2: violation.reading2.mile,
      timestamp2: violation.reading2.timestamp,
      speed: (violation.speed * 100) |> trunc()
    }
  end
end
