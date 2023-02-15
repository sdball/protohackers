defmodule MobInTheMiddle.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:mob_in_the_middle, :port)

    children = [
      {MobInTheMiddle.Supervisor, port: port}
    ]

    opts = [strategy: :one_for_one, name: MobInTheMiddle.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
