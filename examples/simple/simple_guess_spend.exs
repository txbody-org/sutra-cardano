alias Sutra.Cardano.Address
alias Sutra.Cardano.Script
alias Sutra.Provider

import Sutra.Cardano.Transaction.TxBuilder

# Use Provider
Code.eval_file("examples/setup_yaci_provider.exs")

script_code =
  File.read!("./blueprint.json")
  |> :elixir_json.decode()
  |> Map.get("validators", [])
  |> Enum.find(fn v -> v["title"] == "simple.simple.spend" end)
  |> Map.get("compiledCode")
  |> Script.apply_params([Base.encode16("spend-params")])

wallet_address = "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"

sig = "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"

script = %Script{script_type: :plutus_v3, data: script_code}

script_address = Address.from_script(script, :testnet)

place = fn ->
  IO.puts("Placing Utxo to Script with Guess: 42")

  new_tx()
  |> add_output(script_address, %{"lovelace" => 2_000_000}, {:datum_hash, 42})
  |> build_tx!(wallet_address: wallet_address)
  |> sign_tx([sig])
end

place_tx = place.()
place_tx_id = submit_tx(place_tx)

IO.puts("Place Tx Submited with Txid: #{place_tx_id}")

IO.puts("Confirming Tx ....")

Process.sleep(2_000)
{:ok, provider} = Provider.get_fetcher()
new_wallet_utxos = provider.utxos_at([wallet_address]) -- place_tx.tx_body.inputs

input_utxos = provider.utxos_at_refs(["#{place_tx_id}#0"])

spend_tx =
  new_tx()
  |> add_input(input_utxos, witness: script, redeemer: 42, datum: 42)
  |> build_tx!(
    wallet_utxos: new_wallet_utxos,
    wallet_address: wallet_address
  )
  |> sign_tx([sig])

spend_tx_id = submit_tx(spend_tx)

IO.puts("Transaction submitted, Spend: #{spend_tx_id}")
