alias Sutra.Cardano.Script.NativeScript
alias Sutra.Data
alias Sutra.Cardano.Script
alias Sutra.Crypto.Key
import Sutra.Cardano.Transaction.TxBuilder

Code.eval_file("examples/setup_yaci_provider.exs")

mnemonic =
  "test test test test test test test test test test test test test test test test test test test test test test test sauce"

{:ok, root_key} = Key.root_key_from_mnemonic(mnemonic)
{:ok, extended_key} = Key.derive_child(root_key, 0, 0)

{:ok, wallet_address} = Key.address(extended_key, :preprod)

script =
  File.read!("always_true.plutus")
  |> String.trim()
  |> Base.decode16!(case: :mixed)
  |> Script.new(:plutus_v3)

script_json = %{
  "type" => "all",
  "scripts" => [
    %{
      "type" => "sig",
      "keyHash" => wallet_address.payment_credential.hash
    }
  ]
}

tx_id =
  new_tx()
  |> register_stake_credential(script, Data.void())
  |> register_stake_credential(NativeScript.from_json(script_json))
  |> register_stake_credential(wallet_address)
  |> build_tx!(wallet_address: [wallet_address])
  |> sign_tx([extended_key])
  |> sign_tx_with_raw_extended_key(extended_key.stake_key)
  |> submit_tx()

IO.inspect(tx_id)
