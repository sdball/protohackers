defmodule Protohackers.SpeedLimitServer.Camera do
  defstruct [:road, :mile, :limit]

  def new(road, mile, limit) do
    %__MODULE__{road: road, mile: mile, limit: limit}
  end
end
