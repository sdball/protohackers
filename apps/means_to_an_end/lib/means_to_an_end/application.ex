defmodule MeansToAnEnd.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:means_to_an_end, :port)

    children = [
      {MeansToAnEnd, port: port}
    ]

    opts = [strategy: :one_for_one, name: MeansToAnEnd.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
