# Using Reference Inputs

Reference inputs allow you to read data (datum) or use a script (reference script) without spending the UTxO.

## Using a Reference Script

Assuming you have already deployed a script and have its UTxO reference (TxHash#Index).

```elixir
import Sutra.Cardano.Transaction.TxBuilder

# The UTxO holding the reference script
{:ok, provider} = Sutra.Provider.get_fetcher()
[ref_script_utxo] = provider.utxos_at_tx_refs(["tx_hash#index"])

tx_id =
  new_tx()
  |> add_input(
       script_utxo_to_spend, 
       witness: :ref_inputs, # Use reference script
       redeemer: my_redeemer
     )
  # Add the reference input containing the script
  |> add_reference_inputs([ref_script_utxo])
  |> add_output(receiver_address, 5_000_000)
  |> build_tx!(wallet_address: user_address)
  |> sign_tx(user_signing_key)
  |> submit_tx()
```

## Reading Reference Datum

You can also inspect datum from a reference input.

```elixir
  # ...
  |> add_reference_inputs([utxo_with_datum])
  # Logic in your off-chain code or on-chain validator can now access this
  # ...
```
