alias Sutra.Cardano.Address
alias Sutra.Cardano.Asset
alias Sutra.Cardano.Script
alias Sutra.Cardano.Script.NativeScript
alias Sutra.Data

import Sutra.Cardano.Transaction.TxBuilder
# Use Provider
Code.eval_file("examples/setup_yaci_provider.exs")

wallet_address = "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"
sig = "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"

script_json = %{
  "type" => "all",
  "scripts" => [
    %{
      "type" => "sig",
      "keyHash" => Address.from_bech32(wallet_address).payment_credential.hash
    }
  ]
}

script = NativeScript.from_json(script_json)

policy_id = NativeScript.to_script(script) |> Script.hash_script()

assets = %{
  Base.encode16("SUTRA-NATIVE-TKN") => 1
}

tx_id =
  new_tx()
  |> attach_script(script)
  |> mint_asset(policy_id, assets)
  |> pay_to_address(wallet_address, %{
    policy_id => assets
  })
  |> pay_to_address(Address.from_script(policy_id, :testnet), Asset.from_lovelace(1000),
    datum: {:as_hash, Data.encode("check As Hash")}
  )
  |> build_tx!(wallet_address: [wallet_address])
  |> sign_tx([sig])
  |> submit_tx()

IO.puts("Tx Submitted for Mint with Native Script TxId: #{tx_id}")
