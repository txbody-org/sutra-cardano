# Yaci Devkit Integration Guide

## Overview

This guide explains how to integrate the Yaci Devkit into your project.
The Yaci Devkit provides interface to run and manage private network for cardano, accessible through a simple configuration process.

## Getting Started

### 1. Running the Yaci Devkit

For comprehensive information about installing and running the Yaci Devkit, visit the official documentation:
https://devkit.yaci.xyz/

### 2. Basic Integration

Once the Yaci Devkit is running, integrate it into your application by setting `YaciProvider` in your configuration file:

```elixir
# config/config.exs
config :sutra, :provider, YaciProvider
```

### 3. Custom Configuration

If you need to use custom ports or URLs for the Yaci service, you can specify these in your configuration:

```elixir
# config/config.exs
config :sutra, :yaci,
  general_api: "http://localhost:8090/api/v1",  # Replace with your Yaci general API endpoint
  admin_api: "http://localhost:8090/api/v1/admin"  # Replace with your Yaci admin API endpoint
```

## Troubleshooting

If you encounter connection issues:

- Ensure the Yaci Devkit is running properly
- Verify the endpoint URLs are correct
- Check network configuration if running in a containerized environment

For additional help, consult the [Yaci Devkit documentation](https://devkit.yaci.xyz/).
