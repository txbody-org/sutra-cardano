# Helper to setup provider based on ENV
provider_env = System.get_env("PROVIDER")

case provider_env do
  "blockfrost" ->
    project_id = System.get_env("BLOCKFROST_PROJECT_ID")
    network = System.get_env("BLOCKFROST_NETWORK", "preprod") |> String.to_atom()

    Application.put_env(:sutra, :provider, Sutra.Provider.Blockfrost)
    Application.put_env(:sutra, :blockfrost, project_id: project_id, network: network)

  "maestro" ->
    api_key = System.get_env("MAESTRO_API_KEY")
    network = System.get_env("MAESTRO_NETWORK", "preprod") |> String.to_atom()

    Application.put_env(:sutra, :provider, Sutra.Provider.Maestro)
    Application.put_env(:sutra, :maestro, api_key: api_key, network: network)

  "koios" ->
    api_key = System.get_env("KOIOS_API_KEY")
    network = System.get_env("KOIOS_NETWORK", "preprod") |> String.to_atom()

    Application.put_env(:sutra, :provider, Sutra.Provider.Koios)
    Application.put_env(:sutra, :koios, api_key: api_key, network: network)

  _ ->
    # Default behavior (Yaci local) if no PROVIDER set, or fallback
    IO.puts("Warning: PROVIDER env var not set or unknown. Defaulting to Yaci local config.")
    Code.eval_file("examples/setup_yaci_provider.exs")
end
