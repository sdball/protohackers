defmodule UnusualDatabaseProgram.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:unusual_database_program, :port)

    children = [
      {UnusualDatabaseProgram, port: port}
    ]

    opts = [strategy: :one_for_one, name: UnusualDatabaseProgram.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
