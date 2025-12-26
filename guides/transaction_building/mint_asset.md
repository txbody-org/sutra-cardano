# Minting Assets

Minting native assets involves defining a policy (script) and specifying the amount to mint.

```elixir

alias Sutra.Cardano.Script
alias Sutra.Cardano.Asset

# Define a Native Script (Polycal Policy)
policy_script = %Script{
  script_type: :native,
  data: %{
    "type" => "sig",
    "keyHash" => Sutra.Crypto.Key.pubkey_hash(signing_key)
  }
}

policy_id = Script.hash_script(policy_script)
asset_name = "MyToken"
amount = 1000

tx_id =
tx_id =
  Sutra.new_tx()
  |> Sutra.add_input(user_utxos)
  # Mint 1000 tokens
  |> Sutra.mint_asset(
       policy_id, 
       Asset.new(asset_name, amount), 
       policy_script
     )
  # Send minted tokens to a destination (or back to self)
  |> Sutra.add_output(user_address, Asset.new(policy_id, asset_name, amount))
  |> Sutra.build_tx!(wallet_address: user_address)
  |> Sutra.sign_tx(signing_key)
  |> Sutra.submit_tx()
```
