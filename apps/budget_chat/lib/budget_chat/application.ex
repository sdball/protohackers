defmodule BudgetChat.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:budget_chat, :port)

    children = [
      {BudgetChat, port: port}
    ]

    opts = [strategy: :one_for_one, name: BudgetChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
