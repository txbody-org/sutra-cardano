defmodule Sutra.TxExamples.Certificates.DelegateVoteTest do
  @moduledoc false

  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Transaction
  alias Sutra.Data

  use Sutra.PrivnetTest

  import Sutra.Test.Support.BlueprintSupport

  setup_all %{} do
    set_yaci_provider_env()

    with_new_wallet(fn %{signing_key: skey, address: addr} ->
      native_script = always_true_native_script(addr)
      plutus_script = always_true_script()

      Sutra.new_tx()
      |> Sutra.register_stake_credential(addr)
      |> Sutra.register_stake_credential(native_script)
      |> Sutra.register_stake_credential(plutus_script, Data.void())
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

  describe "Delegate vote test" do
    test "delegate vote to drep with address credential", %{wallet_address: addr, skey: skey} do
      assert {:ok, tx} =
               Sutra.new_tx()
               |> Sutra.delegate_vote(addr, Drep.abstain())
               |> Sutra.build_tx(wallet_address: [addr])

      assert tx_id =
               Sutra.sign_tx(tx, [skey])
               |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
               |> Sutra.submit_tx()

      assert Transaction.tx_id(tx) == tx_id
    end

    test "delegate vote to drep with naive script credential", %{
      native_script: native_script,
      skey: native_script_owner_skey
    } do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.delegate_vote(native_script, Drep.abstain())
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 Sutra.sign_tx(tx, [skey, native_script_owner_skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "delegate vote to drep with Plutus script credential", %{plutus_script: plutus_script} do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.delegate_vote(plutus_script, Drep.no_confidence(), Data.void())
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 Sutra.sign_tx(tx, [skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
