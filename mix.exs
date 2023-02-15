defmodule Protohackers.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        echo_server: [
          applications: [echo_server: :permanent]
        ]
      ]
    ]
  end

  defp deps do
    []
  end
end
