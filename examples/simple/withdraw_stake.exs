alias Sutra.Cardano.Script.NativeScript
alias Sutra.Data
alias Sutra.Cardano.Script
alias Sutra.Crypto.Key

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
  Sutra.new_tx()
  |> Sutra.withdraw_stake(script, Data.void(), 0)
  |> Sutra.withdraw_stake(NativeScript.from_json(script_json), 0)
  |> Sutra.withdraw_stake(wallet_address, 0)
  |> Sutra.build_tx!(wallet_address: [wallet_address])
  |> Sutra.sign_tx([extended_key])
  |> Sutra.sign_tx_with_raw_extended_key(extended_key.stake_key)
  |> Sutra.submit_tx()

IO.inspect(tx_id)
