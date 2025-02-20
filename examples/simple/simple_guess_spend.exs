alias Sutra.Cardano.Transaction.Input
alias Sutra.Cardano.Transaction
alias Sutra.Cardano.Transaction.OutputReference
alias Sutra.Data
alias Sutra.Cardano.Address
alias Sutra.Provider.KoiosProvider
alias Sutra.Cardano.Script

import Sutra.Cardano.Transaction.TxBuilder

provider = KoiosProvider.new(network: :preprod)
Application.put_env(:sutra, :provider, provider)

script_code =
  File.read!("./blueprint.json")
  |> :json.decode()
  |> Map.get("validators", [])
  |> Enum.find(fn v -> v["title"] == "simple.simple.spend" end)
  |> Map.get("compiledCode")
  |> Script.apply_params([Base.encode16("spend-params")])

IO.puts(Base.encode16("spend-params"))

wallet_address = "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"
sig = "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"


script = %Script{script_type: :plutus_v3, data: script_code}

script_address = Address.from_script(script, :testnet)

place = fn () ->

IO.puts("Placing Utxo to Script with Guess: 42")

  new_tx()
  |> pay_to_address(script_address, %{"lovelace" => 2_000_000}, datum: {:inline, Data.encode(42)})
  |> build_tx(
    wallet_address: wallet_address,
    collateral_ref: %OutputReference{
      transaction_id: "aedd91887fc765886069f0c4f7e3dce1ba03803133917ab146cd0cf803f8ee96",
      output_index: 3
    }
  )
  |> sign_tx([sig])
end



place_tx = place.()
new_wallet_utxos = KoiosProvider.utxos_at(provider, [wallet_address]) -- place_tx.tx_body.inputs

input_utxos = [
  %Input{
    output_reference: %OutputReference{
      transaction_id: Transaction.tx_id(place_tx),
      output_index: 0
    },
    output: Enum.at(place_tx.tx_body.outputs, 0)
  }
]


spend_tx =
  new_tx()
  |> spend(input_utxos, 42)
  |> attach_script(script)
  |> build_tx(
    wallet_utxos: new_wallet_utxos,
    wallet_address: wallet_address,
    collateral_ref: %OutputReference{
      transaction_id: "aedd91887fc765886069f0c4f7e3dce1ba03803133917ab146cd0cf803f8ee96",
      output_index: 3
    }
  )
  |> sign_tx([sig])

#jplace_tx_id = submit_tx(place_tx)
#spend_tx_id = submit_tx(spend_tx)

#IO.puts("Transaction submitted, Place: #{place_tx_id} \n Spend: #{spend_tx_id}")
