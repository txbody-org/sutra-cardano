# Integrating with Koios

## Overview

Koios is a decentralized and elastic API layer for accessing Cardano blockchain data. This guide explains how to integrate your Elixir application with Koios using the Sutra library.

## Basic Configuration

Add the following configuration to your `config.exs` file:

```elixir
# config.exs
alias Sutra.Provider.KoiosProvider

# Configure the Koios network
config :sutra, :koios,
    network: :preprod

# Set Koios as the provider
config :sutra, :provider, KoiosProvider
```

## Configuration Options

### Network Selection

The `:network` parameter allows you to specify which Cardano network to connect to:

| Value      | Description                                    |
| ---------- | ---------------------------------------------- |
| `:preprod` | Connects to the Cardano pre-production testnet |
| `:mainnet` | Connects to the Cardano mainnet                |
| `:preview` | Connects to the Cardano preview testnet        |

## How It Works

When you set `KoiosProvider` as your provider, all blockchain queries while building Transaction will be routed through the Koios API service.

## Advanced Configuration

For applications with specific requirements, you may want to configure additional options:

```elixir
# config.exs
config :sutra, :koios,
    network: :mainnet,
    timeout: 30_000,        # Request timeout in milliseconds
    retry_attempts: 3,      # Number of retry attempts for failed requests
    batch_size: 100,        # Maximum number of items per batch request
    api_key: "auth-key"     # Api key
```
