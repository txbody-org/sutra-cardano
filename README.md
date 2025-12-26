# Sutra

**Offchain transaction builder framework for Cardano using Elixir.**

## Installation


```elixir
def deps do
  [
    {:sutra_cardano, "~> 0.2.4"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sutra_cardano>.

## Usage

Sutra provides a pipe-friendly API to build transactions.

```elixir
import Sutra

# 1. Create a new transaction
tx =
  new_tx()
  |> use_provider(MyProvider) # Configure your provider (Blockfrost, Yaci, etc.)
  |> add_input(utxos)
  |> add_output(friend_address, 10_000_000)

# 2. Build and Sign
signed_tx =
  tx
  |> build_tx!()
  |> sign_tx(private_key)

# 3. Submit
submit_tx(signed_tx)
```

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