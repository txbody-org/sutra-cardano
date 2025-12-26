defmodule Sutra.TxExamples.WithdrawRewardTest do
  @moduledoc false

  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Transaction
  alias Sutra.Data

  use Sutra.PrivnetTest

  import Sutra.Test.Support.BlueprintSupport

  @yaci_pool_id "pool1wvqhvyrgwch4jq9aa84hc8q4kzvyq2z3xr6mpafkqmx9wce39zy"

  setup_all %{} do
    set_yaci_provider_env()

    with_new_wallet(fn %{signing_key: skey, address: addr} ->
      native_script = always_true_native_script(addr)
      plutus_script = always_true_script()

      Sutra.new_tx()
      |> Sutra.delegate_stake_and_vote(addr, Drep.abstain(), @yaci_pool_id)
      |> Sutra.delegate_stake_and_vote(native_script, Drep.abstain(), @yaci_pool_id)
      |> Sutra.delegate_stake_and_vote(
        plutus_script,
        Drep.no_confidence(),
        @yaci_pool_id,
        Data.void()
      )
      |> Sutra.build_tx!(wallet_address: [addr])
      |> Sutra.sign_tx([skey])
      |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
      |> Sutra.submit_tx()
      |> await_tx()

      {:ok,
       wallet_address: addr,
       skey: skey,
       native_script: native_script,
       plutus_script: plutus_script}
    end)
  end

  describe "Withdraw Reward Test" do
    test "withdraw reward from address credential", %{wallet_address: addr, skey: skey} do
      assert {:ok, tx} =
               Sutra.new_tx()
               |> Sutra.withdraw_stake(addr, 0)
               |> Sutra.build_tx(wallet_address: [addr])

      assert tx_id =
               Sutra.sign_tx(tx, skey)
               |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
               |> Sutra.submit_tx()

      assert Transaction.tx_id(tx) == tx_id
    end

    test "withdraw reward from native_script credential", %{
      skey: native_script_owner_skey,
      native_script: native_script
    } do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.withdraw_stake(native_script, 0)
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 Sutra.sign_tx(tx, [skey, native_script_owner_skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "withdraw reward from plutus_script credential", %{
      plutus_script: plutus_script
    } do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.withdraw_stake(plutus_script, Data.void(), 0)
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 Sutra.sign_tx(tx, [skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
