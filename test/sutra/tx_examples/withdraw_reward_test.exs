defmodule Sutra.TxExamples.WithdrawRewardTest do
  @moduledoc false
  alias Sutra.Data
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Common.Drep

  use Sutra.PrivnetTest

  import Sutra.Test.Support.BlueprintSupport
  import Sutra.Cardano.Transaction.TxBuilder

  @yaci_pool_id "pool1wvqhvyrgwch4jq9aa84hc8q4kzvyq2z3xr6mpafkqmx9wce39zy"

  setup_all %{} do
    set_yaci_provider_env()

    with_new_wallet(fn %{signing_key: skey, address: addr} ->
      native_script = always_true_native_script(addr)
      plutus_script = always_true_script()

      new_tx()
      |> delegate_stake_and_vote(addr, Drep.abstain(), @yaci_pool_id)
      |> delegate_stake_and_vote(native_script, Drep.abstain(), @yaci_pool_id)
      |> delegate_stake_and_vote(
        plutus_script,
        Drep.no_confidence(),
        @yaci_pool_id,
        Data.void()
      )
      |> build_tx!(wallet_address: [addr])
      |> sign_tx([skey])
      |> sign_tx_with_raw_extended_key(skey.stake_key)
      |> submit_tx()
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
               new_tx()
               |> withdraw_stake(addr, 0)
               |> build_tx(wallet_address: [addr])

      assert tx_id =
               sign_tx(tx, skey)
               |> sign_tx_with_raw_extended_key(skey.stake_key)
               |> submit_tx()

      assert Transaction.tx_id(tx) == tx_id
    end

    test "withdraw reward from native_script credential", %{
      skey: native_script_owner_skey,
      native_script: native_script
    } do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 new_tx()
                 |> withdraw_stake(native_script, 0)
                 |> build_tx(wallet_address: [addr])

        assert tx_id =
                 sign_tx(tx, [skey, native_script_owner_skey])
                 |> submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "withdraw reward from plutus_script credential", %{
      plutus_script: plutus_script
    } do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 new_tx()
                 |> withdraw_stake(plutus_script, Data.void(), 0)
                 |> build_tx(wallet_address: [addr])

        assert tx_id =
                 sign_tx(tx, [skey])
                 |> submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
