defmodule SpeedDaemon.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:speed_daemon, :port)

    children = [
      {SpeedDaemon.Supervisor, port: port}
    ]

    opts = [strategy: :one_for_one, name: SpeedDaemon.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
