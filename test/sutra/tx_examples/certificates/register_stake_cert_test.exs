defmodule Sutra.TxExamples.Certificates.RegisterStakeCertTest do
  @moduledoc false
  alias Sutra.Data
  alias Sutra.Cardano.Transaction

  use Sutra.PrivnetTest

  import Sutra.Test.Support.BlueprintSupport,
    only: [always_true_script: 0, always_true_native_script: 1]

  import Sutra.Cardano.Transaction.TxBuilder

  describe "Register Stake Credential Test" do
    test "register stake credential test with Address Credential" do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 new_tx() |> register_stake_credential(addr) |> build_tx(wallet_address: [addr])

        assert tx_id =
                 tx
                 |> sign_tx([skey])
                 |> sign_tx_with_raw_extended_key(skey.stake_key)
                 |> submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "register stake credential with Native Script" do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 new_tx()
                 |> register_stake_credential(always_true_native_script(addr))
                 |> build_tx(wallet_address: [addr])

        assert tx_id =
                 tx
                 |> sign_tx([skey])
                 |> submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "register stake credential with Plutus Script" do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 new_tx()
                 |> register_stake_credential(always_true_script(), Data.void())
                 |> build_tx(wallet_address: [addr])

        assert tx_id =
                 tx
                 |> sign_tx([skey])
                 |> submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
