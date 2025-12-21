# Setting up Provider

Sutra SDK supports multiple Cardano providers. You can verify and use any of the supported providers by configuring them in your `config/config.exs` or explicitly passing options.

## Blockfrost

Blockfrost is a popular API provider for Cardano.

### Configuration

Add the following to your `config/config.exs`:

```elixir
config :sutra, :blockfrost,
    project_id: System.get_env("BLOCKFROST_PROJECT_ID"),
    network: :preprod, # or :mainnet, :preview
    base_url: nil # Optional override
```

### Usage

```elixir
alias Sutra.Provider.Blockfrost
# Create a client explicitly if needed, or rely on global config
```

## Maestro

Maestro provides high-fidelity blockchain data access.

### Configuration

```elixir
config :sutra, :maestro,
    api_key: System.get_env("MAESTRO_API_KEY"),
    network: :preprod, # or :mainnet, :preview
    base_url: nil # Optional override
```

## KupoOgmios

For self-hosted or local setups using Kupo and Ogmios.

### Configuration

```elixir
config :sutra, :kupogmios,
    kupo_base_url: "http://localhost:1442",
    ogmios_base_url: "http://localhost:1337",
    network: :preprod
```

## Koios

Koios is a decentralized and elastic RESTful API.

### Configuration

```elixir
config :sutra, :koios,
    api_key: System.get_env("KOIOS_API_KEY"), # Optional for public tier
    network: :preprod # or :mainnet, :preview
```

## Yaci

Yaci DevKit is a local development environment.

### Configuration

```elixir
config :sutra, :yaci,
  yaci_general_api_url: "http://localhost:8080", # Defaults to http://localhost:8080
  yaci_admin_api_url: "http://localhost:10000" # Defaults to http://localhost:10000
```

To use a specific provider globally, you can set the `:provider` key in your config:

```elixir
config :sutra, :provider, Sutra.Provider.Blockfrost 
# or Sutra.Provider.Maestro, etc.
```

Or configure separate fetcher and submitter:

```elixir
config :sutra, :provider,
  fetch_with: Sutra.Provider.Blockfrost,
  submit_with: Sutra.Provider.Maestro
```
