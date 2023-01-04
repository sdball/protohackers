defmodule Protohackers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children(Mix.env()), opts)
  end

  defp children(:prod) do
    [
      {Protohackers.EchoServer, 11235},
      {Protohackers.IsPrimeServer, 11236}
    ]
  end

  defp children(_other) do
    [
      {Protohackers.EchoServer, 11235},
      {Protohackers.IsPrimeServer, 11236}
    ]
  end
end
