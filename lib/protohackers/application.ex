defmodule Protohackers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Protohackers.EchoServer, 11235},
      {Protohackers.IsPrimeServer, 11236},
      {Protohackers.AssetPriceServer, 11237},
      {Protohackers.ChatRoomServer, 11238},
      {Protohackers.UnusualDatabaseProtocolServer, 11239},
      {Protohackers.MobInTheMiddleServer, 11240}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
