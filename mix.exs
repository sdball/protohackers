defmodule Protohackers.MixProject do
  use Mix.Project

  def project do
    [
      app: :protohackers,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Protohackers.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4.0"},
      {:benchee, "~> 1.1.0", only: :dev},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
