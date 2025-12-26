# Deploying Scripts

To use reference scripts (CIP-33), you first need to "deploy" the script to the blockchain by sending it to an output.

```elixir
import Sutra.Cardano.Transaction.TxBuilder
alias Sutra.Cardano.Script
alias Sutra.Cardano.Address

# Your Plutus Script
script = %Script{
  script_type: :plutus_v2,
  data: "..." # CBOR hex of the script
}

tx_id =
  new_tx()
  |> add_input(user_utxos)
  # Deploy script to an address
  # This creates an output with the script attached as a reference script
  # and a minimal ADA amount.
  |> deploy_script(%Address{}, script)
  |> build_tx!(wallet_address: user_address)
  |> sign_tx(signing_key)
  |> submit_tx()
```

Once confirmed, you can use the resulting UTxO as a reference input in future transactions.
