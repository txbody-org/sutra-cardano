# Kupo & Ogmios Integration Guide

## Overview

This guide explains how to integrate Kupo and Ogmios services with your Elixir application.

## Prerequisites

- Working installations of [Kupo](https://github.com/CardanoSolutions/kupo) and [Ogmios](https://github.com/CardanoSolutions/ogmios)

## Configuration

Add the following configuration to your `config.exs` file:

```elixir
alias Sutra.Provider.Kupogmios

# Set Kupo and Ogmios as your provider
config :sutra, :provider, Kupogmios

# Configure connection details
config :sutra, :kupogmios,
  network: :preprod,                   # Options: :mainnet, :preprod, :preview
  ogmios_url: "http://localhost:1337", # Replace with your Ogmios service URL
  kupo_url: "http://localhost:1442"    # Replace with your Kupo service URL
```

### Network Options

The `network` parameter accepts the following values:

- `:mainnet` - Production Cardano network
- `:preprod` - Pre-production test network
- `:preview` - Preview test network

### Custom Ports

If you're running Kupo and Ogmios with non-default ports:

```elixir
config :sutra, :kupogmios,
  network: :mainnet,
  ogmios_url: "http://your-server:8082",  # Custom Ogmios port
  kupo_url: "http://your-server:8081"     # Custom Kupo port
```

## Additional Resources

- [Kupo Documentation](https://github.com/CardanoSolutions/kupo)
- [Ogmios Documentation](https://github.com/CardanoSolutions/ogmios)
