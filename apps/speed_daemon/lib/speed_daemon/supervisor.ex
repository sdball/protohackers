defmodule SpeedDaemon.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl true
  def init(port: port) do
    registry_opts = [
      name: SpeedDaemon.DispatchersRegistry,
      keys: :duplicate,
      listeners: [SpeedDaemon.CentralTicketDispatcher]
    ]

    # TODO: replace CentralTicketDispatcher with Dispatcher per road
    # Need another registry to route to the Dispatcher per road
    # Need another supervisor to manage road registries
    children = [
      {Registry, registry_opts},
      SpeedDaemon.CentralTicketDispatcher,
      SpeedDaemon.ConnectionSupervisor,
      {SpeedDaemon.Acceptor, port}
    ]

    # :rest_for_one
    # if a process crashes then it any any children declared after it will be restarted
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
