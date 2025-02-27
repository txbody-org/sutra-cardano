alias Sutra.Provider.Kupogmios
alias Sutra.Utils

resp =
  Req.get!("http://localhost:10000/local-cluster/api/admin/devnet/genesis/shelley").body

{:ok, zero_time, _} =
  DateTime.from_iso8601(resp["systemStart"])

slot_config = %Sutra.SlotConfig{
  zero_time: DateTime.to_unix(zero_time, :millisecond),
  slot_length: resp["slotLength"] * 1000,
  zero_slot: 0
}

Application.put_env(:sutra, :kupogmios,
  network: :custom,
  ogmios_url: "http://localhost:1337",
  kupo_url: "http://localhost:1442",
  slot_config: slot_config
)

Application.put_env(:sutra, :provider, Kupogmios)
