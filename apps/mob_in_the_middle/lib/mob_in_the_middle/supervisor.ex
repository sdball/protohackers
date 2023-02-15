defmodule MobInTheMiddle.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl true
  def init(port: port) do
    children = [
      MobInTheMiddle.ConnectionSupervisor,
      {MobInTheMiddle.Acceptor, port: port}
    ]

    # :rest_for_one
    # if a process crashes then it **and** any children defined after it will be restarted
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
