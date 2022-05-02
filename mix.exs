defmodule Balancero.MixProject do
  use Mix.Project

  def project do
    [
      app: :balancero,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        test: "test --no-start"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:connection, "~> 1.1"},
      {:phoenix_pubsub, "~> 2.0"},
      {:local_cluster, "~> 1.2", only: :test}
    ]
  end
end
