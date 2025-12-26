defmodule Sutra.TxExamples.Certificates.DelegatePoolAndDrepTest do
  @moduledoc false

  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Transaction
  alias Sutra.Data
  alias Sutra.Test.Support.BlueprintSupport

  use Sutra.PrivnetTest

  @yaci_pool_id "pool1wvqhvyrgwch4jq9aa84hc8q4kzvyq2z3xr6mpafkqmx9wce39zy"

  describe "Delegate To Pool and Drep in single Tx" do
    test "delegate to pool and drep with address credential" do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.delegate_stake_and_vote(addr, Drep.abstain(), @yaci_pool_id)
                 |> Sutra.build_tx(wallet_address: addr)

        assert tx_id =
                 Sutra.sign_tx(tx, [skey])
                 |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "delegate to pool and drep with native script credential" do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.delegate_stake_and_vote(
                   BlueprintSupport.always_true_native_script(addr),
                   Drep.abstain(),
                   @yaci_pool_id
                 )
                 |> Sutra.build_tx(wallet_address: addr)

        assert tx_id =
                 Sutra.sign_tx(tx, [skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "delegate to pool and drep with plutus script credential" do
      with_new_wallet(fn %{address: addr, signing_key: skey} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.delegate_stake_and_vote(
                   BlueprintSupport.always_true_script(),
                   Drep.abstain(),
                   @yaci_pool_id,
                   Data.void()
                 )
                 |> Sutra.build_tx(wallet_address: addr)

        assert tx_id =
                 Sutra.sign_tx(tx, [skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
