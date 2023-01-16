defmodule Protohackers.SpeedLimitServer.Dispatcher do
  defstruct [:roads]

  def new(roads_bytes) do
    roads = parse_roads(roads_bytes)
    %__MODULE__{roads: roads}
  end

  def parse_roads(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.chunk_every(2)
    |> Enum.map(fn chunk ->
      <<road::16>> = :binary.list_to_bin(chunk)
      road
    end)
  end
end
