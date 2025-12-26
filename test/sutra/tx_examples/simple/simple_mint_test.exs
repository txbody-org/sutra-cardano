defmodule Sutra.TxExamples.Simple.SimpleMintTest do
  @moduledoc false

  use Sutra.PrivnetTest

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Data
  alias Sutra.Provider.Yaci

  import Sutra.Test.Support.BlueprintSupport, only: [get_simple_script: 1]

  @mint_asset %{Base.encode16("token1", case: :lower) => 100}

  describe "Simple Mint" do
    setup _ do
      script =
        get_simple_script("simple.simple.mint")
        |> Script.apply_params([Base.encode16("some-params")])
        |> Script.new(:plutus_v3)

      policy_id = Script.hash_script(script)

      {:ok, script: script, policy_id: policy_id}
    end

    test "can mint token with plutusv3 Script", %{script: script, policy_id: policy_id} do
      with_new_wallet(fn %{signing_key: signing_key, address: addr} ->
        to_address = random_address()

        tx =
          Sutra.new_tx()
          |> Sutra.attach_metadata(123, "Test Sutra TX")
          |> Sutra.mint_asset(policy_id, @mint_asset, script, Data.void())
          |> Sutra.add_output(
            to_address,
            %{policy_id => @mint_asset},
            {:inline_datum, Data.encode(58)}
          )
          |> Sutra.build_tx!(wallet_address: addr)

        submit_tx_id =
          tx
          |> Sutra.sign_tx([signing_key])
          |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == submit_tx_id
        await_tx(submit_tx_id)

        assert %{policy_id => @mint_asset} ==
                 Yaci.balance_of(to_address) |> Asset.without_lovelace()
      end)
    end

    test "Can also mint using Ref Script", %{script: script, policy_id: policy_id} do
      with_new_wallet(fn %{signing_key: signing_key, address: addr} ->
        to_address = random_address()

        ref_tx_id =
          Sutra.new_tx()
          |> Sutra.deploy_script(to_address, script)
          |> Sutra.build_tx!(wallet_address: addr)
          |> Sutra.sign_tx([signing_key])
          |> Sutra.submit_tx()

        await_tx(ref_tx_id)

        ref_utxos = Yaci.utxos_at_tx_refs(["#{ref_tx_id}#0"])

        mint_tx_id =
          Sutra.new_tx()
          |> Sutra.add_reference_inputs(ref_utxos)
          |> Sutra.mint_asset(policy_id, @mint_asset, :ref_inputs, Data.void())
          |> Sutra.add_output(
            to_address,
            %{policy_id => @mint_asset},
            {:inline_datum, Data.encode(58)}
          )
          |> Sutra.build_tx!(wallet_address: addr)
          |> Sutra.sign_tx([signing_key])
          |> Sutra.submit_tx()

        await_tx(mint_tx_id)

        assert %{policy_id => @mint_asset} ==
                 Yaci.balance_of(to_address) |> Asset.without_lovelace()
      end)
    end
  end
end
