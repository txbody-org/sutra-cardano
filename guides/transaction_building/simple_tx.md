# Transaction Building

Sutra SDK provides a composable `TxBuilder` module to construct, sign, and submit Cardano transactions.

## Basic Flow

The general pattern for building a transaction is:

1.  Initialize with `new_tx()`
2.  Add inputs (`add_input`)
3.  Add outputs (`add_output`)
4.  (Optional) Mint assets, deploy scripts, add metadata, etc.
5.  Build the transaction body (`build_tx!`)
6.  Sign (`sign_tx`)
7.  Submit (`submit_tx`)

## Example: Simple Payment

Here is a complete example of sending ADA from one wallet to another.

```elixir
alias Sutra.Cardano.Transaction.TxBuilder


# 1. Fetch Inputs
{:ok, provider} = Sutra.Provider.get_fetcher()
user_utxos = provider.utxos_at_addresses([user_address])

# 2. Build Transaction
tx_id = 
tx_id = 
  Sutra.new_tx()
  # Spend from user
  |> Sutra.add_input(user_utxos) 
  # Pay 5 ADA to receiver
  |> Sutra.add_output(receiver_address, 5_000_000) 
  # Balance and build (calculates fees, change)
  |> Sutra.build_tx!(wallet_address: user_address) 
  # Sign
  |> Sutra.sign_tx(user_signing_key)
  # Submit
  |> Sutra.submit_tx()

IO.puts("Tx Submitted: #{tx_id}")
```

## Key Functions

### `new_tx()`
Initializes a new transaction builder state.

### `add_input(builder, inputs, opts \\ [])`
Adds specific UTxOs to spend.
- **opts**:
  - `witness`: Script or key witness (default: `:vkey_witness`).
  - `redeemer`: Redeemer data if spending from a script.

### `add_output(builder, address, amount, datum \\ nil)`
Adds an output to the transaction.
- `datum`: Can be `{:inline_datum, data}` or `{:datum_hash, data}`.

### `build_tx!(builder, opts)`
Finalizes the transaction body.
- `wallet_address`: (Required) Address to send change to and use for balancing.
- `wallet_utxos`: (Optional) Extra UTxOs to use for balancing if inputs aren't enough.

### `sign_tx(builder, signers)`
Signs the transaction. `signers` can be a list of signing keys (Sutra.Crypto.Key) or Bech32 private key strings.

### `submit_tx(builder)`
Submits the signed transaction using the configured provider.
