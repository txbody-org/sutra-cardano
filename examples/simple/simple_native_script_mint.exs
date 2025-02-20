
alias Sutra.Provider.KoiosProvider
alias Sutra.Cardano.Script
alias Sutra.Cardano.Script.NativeScript
alias Sutra.Cardano.Address
alias Sutra.Cardano.Transaction.OutputReference

import Sutra.Cardano.Transaction.TxBuilder

provider = KoiosProvider.new(network: :preprod)
Application.put_env(:sutra, :provider, provider)


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

tx_id = new_tx()
  |> mint_asset(policy_id, assets)
  |> attach_script(script)
  |> pay_to_address(wallet_address, %{policy_id => assets})
  |> build_tx(
      wallet_address: wallet_address,
      collateral_ref: %OutputReference{
        transaction_id: "aedd91887fc765886069f0c4f7e3dce1ba03803133917ab146cd0cf803f8ee96", 
        output_index: 3
      }
  )
  |> sign_tx([sig])
  |> submit_tx(provider)


IO.puts("Tx Submitted for Mint with Native Script TxId: #{tx_id}")
