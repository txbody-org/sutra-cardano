# Use Provider
Code.eval_file("examples/setup_kupogmios_provider.exs")

alias Sutra.Cardano.Script.NativeScript
alias Sutra.Provider.Kupogmios
alias Sutra.Cardano.Asset
alias Sutra.Data
alias Sutra.Cardano.Script
alias Sutra.Cardano.Address

import Sutra.Cardano.Transaction.TxBuilder

blueprint = File.read!("./blueprint.json") |> :json.decode()

user_address = "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"

simple_mint_script =
  blueprint
  |> Map.get("validators", [])
  |> Enum.find(fn v -> v["title"] == "simple.simple.mint" end)
  |> Map.get("compiledCode")
  |> Script.apply_params([Base.encode16("some-params")])
  |> Script.new(:plutus_v3)

script_json = %{
  "type" => "all",
  "scripts" => [
    %{
      "type" => "sig",
      "keyHash" => Address.from_bech32(user_address).payment_credential.hash
    }
  ]
}

native_script = NativeScript.from_json(script_json)
native_policy_id = Script.hash_script(native_script)

native_asset = %{
  Base.encode16("SUTRA-NATIVE-TKN") => 1
}

mint_script_address = Address.from_script(simple_mint_script, :preprod)

out_token_name = Base.encode16("SUTRA-SDK-TEST")
policy_id = Script.hash_script(simple_mint_script)

out_value =
  Asset.zero()
  |> Asset.add(policy_id, out_token_name, 100)

current_posix_time = System.os_time(:millisecond)

IO.puts("Deploying Script ....")

script_tx =
  new_tx()
  |> deploy_script(user_address, simple_mint_script)
  |> deploy_script(user_address, native_script)
  |> build_tx!(wallet_address: user_address)

script_tx_id =
  script_tx
  |> sign_tx(["ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"])
  |> submit_tx()

IO.puts("Fetching Ref script")
Process.sleep(2_000)
script_utxo = Kupogmios.utxos_at_refs(["#{script_tx_id}#0", "#{script_tx_id}#1"])

tx =
  new_tx()
  |> attach_metadata(123, "Test Sutra TX")
  |> mint_asset(policy_id, %{out_token_name => 100}, Data.void())
  |> mint_asset(native_policy_id, native_asset)
  |> reference_inputs(script_utxo)
  |> pay_to_address(mint_script_address, out_value, datum: {:inline, Data.encode(58)})
  |> pay_to_address(user_address, %{native_policy_id => native_asset},
    datum: {:as_hash, Data.encode(4)}
  )
  |> valid_from(current_posix_time)
  |> valid_to(current_posix_time + 20 * 60 * 1000)
  |> build_tx!(wallet_address: user_address)

tx_id =
  tx
  |> sign_tx(["ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"])
  |> submit_tx()

IO.puts("Transaction Submitted with TxId: #{tx_id}")
