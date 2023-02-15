defmodule PrimeTime.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:prime_time, :port)

    children = [
      {PrimeTime, port: port}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PrimeTime.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
