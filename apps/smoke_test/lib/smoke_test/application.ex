defmodule SmokeTest.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:smoke_test, :port)

    children = [
      {SmokeTest, port: port}
    ]

    opts = [strategy: :one_for_one, name: SmokeTest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
