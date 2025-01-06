defmodule Sutra.MixProject do
  use Mix.Project

  def project do
    [
      app: :sutra_offchain,
      version: "0.1.0",
      elixir: "~> 1.18.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixture"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:cbor, "~> 1.0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:blake2_elixir, "~> 0.8.1"},
      {:typed_struct, "~> 0.3.0"},
      {:rustler, "~> 0.35.0"},
      {:bech32, "~> 1.0"}
    ]
  end
end
