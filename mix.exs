defmodule Sutra.MixProject do
  use Mix.Project

  def project do
    [
      app: :sutra,
      version: "0.2.1-alpha",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,

      # Docs
      name: "Sutra",
      source_url: "https://github.com/txbody-org/sutra-cardano",
      homepage_url: "https://github.com/txbody-org/sutra-cardano",
      docs: &docs/0
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
      {:blake2_elixir, "~> 0.9.0"},
      {:typed_struct, "~> 0.3.0"},
      {:rustler, "~> 0.36.2"},
      {:bech32, "~> 1.0"},
      {:req, "~> 0.5.7"},
      {:mnemonic, git: "https://github.com/piyushthapa/mnemonic"},
      {:ex_sodium, git: "https://github.com/txbody-org/ex_sodium"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "overview",
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  defp extras do
    [
      "guides/overview.md",
      # Provider Guides
      "guides/provider_integration/yaci_devkit.md",
      "guides/provider_integration/kupogmios.md",
      "guides/provider_integration/koios.md",

      # Transaction Building
      "guides/transaction_building/simple_tx.md",
      "guides/transaction_building/mint_asset.md",
      "guides/transaction_building/deploy_script.md",
      "guides/transaction_building/reference_inputs.md"
    ]
  end

  defp groups_for_extras do
    [
      Provider: ~r/guides\/provider_integration\/.?/,
      Script: ~r/guides\/script\/.?/,
      Transaction: ~r/guides\/transaction_building\/.?/
    ]
  end
end
