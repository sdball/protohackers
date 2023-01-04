defmodule Protohackers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children(Mix.env()), opts)
  end

  defp children(:prod) do
    # right now I only now how to have one port open from fly.io
    [{Protohackers.IsPrimeServer, 8080}]
  end

  defp children(_other) do
    [
      {Protohackers.EchoServer, 11235},
      {Protohackers.IsPrimeServer, 11236}
    ]
  end
end
