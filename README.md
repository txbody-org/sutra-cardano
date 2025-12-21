# Sutra

** Offchain transaction builder framework for cardano using Elixir.**

> [!WARNING]  
> SDK is under heavy development and API might change until we have stable version.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sutra_offchain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sutra, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sutra_offchain>.

## Supported Providers

Sutra SDK supports multiple providers for interacting with the Cardano blockchain:

- **Blockfrost**
- **Maestro**
- **Koios**
- **Yaci DevKit** (Local Development)
- **Kupo / Ogmios**

## Configuration

For detailed setup instructions for each provider, please refer to the [Provider Setup Guide](guides/provider_integration/setup_provider.md).

Quick example for Yaci (Local):

```elixir
config :sutra, :provider, Sutra.Provider.Yaci

config :sutra, :yaci,
  yaci_general_api_url: "http://localhost:8080",
  yaci_admin_api_url: "http://localhost:10000"
```

## Running Examples

1. Set up your provider credentials (see [Setup Guide](guides/provider_integration/setup_provider.md)).
2. Use the example scripts in `examples/` folder.
3. For local development with Yaci, ensure Yaci DevKit is running.

```bash
# Example: Running a simple mint transaction
mix run examples/simple/simple_mint.exs
```