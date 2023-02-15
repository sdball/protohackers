defmodule MobInTheMiddle.Acceptor do
  # temporary - do not restart task for any kind of exit
  # transient - restart for non-successful exits
  # permanent - always restart task on exit
  use Task, restart: :transient

  require Logger

  def start_link(port: port) do
    Task.start_link(__MODULE__, :run, [port])
  end

  def run(port) do
    listen_options = [
      # receive data as binaries (instead of lists)
      mode: :binary,
      # receive incoming packets as messages
      active: :once,
      # allow reusing the address if the listener crashes
      reuseaddr: true,
      # keep the peer socket open after the client closes its writes
      exit_on_close: false,
      # automatically split inputs by newline
      packet: :line,
      # increase default buffer to 10KB
      buffer: 1024 * 10
    ]

    with {:ok, listen_socket} <- :gen_tcp.listen(port, listen_options) do
      Logger.info("MobInTheMiddle Acceptor started listening port=#{port}")
      accept_loop(listen_socket)
    else
      {:error, reason} ->
        raise "MobInTheMiddle Acceptor failed to start listening port=#{port} reason=#{inspect(reason)}"
    end
  end

  def accept_loop(listen_socket) do
    with {:ok, socket} <- :gen_tcp.accept(listen_socket) do
      Logger.info("MobInTheMiddle Acceptor accepted connection socket=#{inspect(socket)}")
      MobInTheMiddle.ConnectionSupervisor.start_child(socket)
      accept_loop(listen_socket)
    else
      {:error, reason} ->
        raise "MobInTheMiddle Acceptor failed to accept connection reason=#{inspect(reason)}"
    end
  end
end
