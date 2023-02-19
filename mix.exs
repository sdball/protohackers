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
        smoke_test: [
          applications: [smoke_test: :permanent]
        ],
        prime_time: [
          applications: [prime_time: :permanent]
        ],
        means_to_an_end: [
          applications: [means_to_an_end: :permanent]
        ],
        budget_chat: [
          applications: [budget_chat: :permanent]
        ],
        unusual_database_program: [
          applications: [unusual_database_program: :permanent]
        ],
        mob_in_the_middle: [
          applications: [mob_in_the_middle: :permanent]
        ],
        speed_daemon: [
          applications: [speed_daemon: :permanent]
        ],
        line_reversal: [
          applications: [line_reversal: :permanent]
        ]
      ]
    ]
  end

  defp deps do
    []
  end
end
