defmodule Sutra.TxExamples.Certificates.RegisterStakeCertTest do
  @moduledoc false

  alias Sutra.Cardano.Transaction
  alias Sutra.Data

  use Sutra.PrivnetTest

  import Sutra.Test.Support.BlueprintSupport,
    only: [always_true_script: 0, always_true_native_script: 1]

  describe "Register Stake Credential Test" do
    test "register stake credential test with Address Credential" do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.register_stake_credential(addr)
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 tx
                 |> Sutra.sign_tx([skey])
                 |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "register stake credential with Native Script" do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.register_stake_credential(always_true_native_script(addr))
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 tx
                 |> Sutra.sign_tx([skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end

    test "register stake credential with Plutus Script" do
      with_new_wallet(fn %{signing_key: skey, address: addr} ->
        assert {:ok, tx} =
                 Sutra.new_tx()
                 |> Sutra.register_stake_credential(always_true_script(), Data.void())
                 |> Sutra.build_tx(wallet_address: [addr])

        assert tx_id =
                 tx
                 |> Sutra.sign_tx([skey])
                 |> Sutra.submit_tx()

        assert Transaction.tx_id(tx) == tx_id
      end)
    end
  end
end
