alias Sutra.Provider.KoiosProvider

Application.put_env(:sutra, :koios, network: :preprod)
Application.put_env(:sutra, :provider, fetch_with: KoiosProvider, submit_with: KoiosProvider)
