defmodule Protohackers.MITM.Supervisor do
  use Supervisor

  def start_link(port: port) do
    Supervisor.start_link(__MODULE__, port: port)
  end

  @impl true
  def init(port: port) do
    children = [
      Protohackers.MITM.ConnectionSupervisor,
      {Protohackers.MITM.Acceptor, port}
    ]

    # :rest_for_one
    # if a process crashes then it **and** any children defined after it will be restarted
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
