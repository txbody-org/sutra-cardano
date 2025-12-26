alias Sutra.Cardano.Common.Drep
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
  |> Script.apply_params(Base.encode16(:rand.bytes(12)))

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
  |> Sutra.delegate_vote(script, Drep.abstain(), Data.void())
  |> Sutra.delegate_vote(NativeScript.from_json(script_json), Drep.no_confidence())
  |> Sutra.delegate_vote(wallet_address, Drep.abstain())
  |> Sutra.build_tx!(wallet_address: [wallet_address])
  |> Sutra.sign_tx([extended_key])
  |> Sutra.sign_tx_with_raw_extended_key(extended_key.stake_key)
  |> Sutra.submit_tx()

IO.inspect(tx_id)
