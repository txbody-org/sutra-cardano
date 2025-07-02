defmodule Sutra.TxExamples.Simple.SimpleSpendTest do
  @moduledoc false

  use Sutra.PrivnetTest

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Data
  alias Sutra.Provider.YaciProvider

  import Sutra.Test.Support.BlueprintSupport
  import Sutra.Cardano.Transaction.TxBuilder

  describe "Simple Spend from script" do
    test "collects inputs from script if guessed number is correct" do
      with_new_wallet(fn %{signing_key: signing_key, address: addr} ->
        script =
          get_simple_script("simple.simple.spend")
          |> Script.apply_params([Base.encode16("some-params-guess")])
          |> Script.new(:plutus_v3)

        script_addr = Address.from_script(script, :preprod)

        place_tx_id =
          new_tx()
          |> pay_to_address(script_addr, Asset.from_lovelace(2_000_000),
            datum: {:inline, Data.encode(100)}
          )
          |> build_tx!(wallet_address: addr)
          |> sign_tx([
            signing_key,
            "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"
          ])
          |> submit_tx()

        await_tx(place_tx_id)

        script_guess_utxo = YaciProvider.utxos_at_refs(["#{place_tx_id}#0"])

        spend_tx_id =
          new_tx()
          # spending with redeemer 100 which matches with datum set in place Tx
          |> spend(script_guess_utxo, 100)
          |> attach_script(script)
          |> build_tx!(wallet_address: addr)
          |> sign_tx([signing_key])
          |> submit_tx()

        await_tx(spend_tx_id)

        # should return nil for place_tx_id since it is already spent
        place_utxo =
          YaciProvider.utxos_at([script_addr])
          |> Enum.find(fn %Input{output_reference: oref} ->
            oref.transaction_id == place_tx_id
          end)

        assert is_nil(place_utxo)
      end)
    end
  end
end
