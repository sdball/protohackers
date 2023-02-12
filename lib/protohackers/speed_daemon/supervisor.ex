defmodule Protohackers.SpeedDaemon.Supervisor do
  use Supervisor

  def start_link(port: port) do
    Supervisor.start_link(__MODULE__, port: port)
  end

  @impl true
  def init(port: port) do
    registry_opts = [
      name: Protohackers.SpeedDaemon.DispatchersRegistry,
      keys: :duplicate,
      listeners: [Protohackers.SpeedDaemon.CentralTicketDispatcher]
    ]

    # TODO: replace CentralTicketDispatcher with Dispatcher per road
    # Need another registry to route to the Dispatcher per road
    # Need another supervisor to manage road registries
    children = [
      {Registry, registry_opts},
      Protohackers.SpeedDaemon.CentralTicketDispatcher,
      Protohackers.SpeedDaemon.ConnectionSupervisor,
      {Protohackers.SpeedDaemon.Acceptor, port}
    ]

    # :rest_for_one
    # if a process crashes then it **and** any children defined after it will be restarted
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
