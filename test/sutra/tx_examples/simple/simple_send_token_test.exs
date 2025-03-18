defmodule Sutra.TxExamples.Simple.SimpleSendTokenTest do
  @moduledoc false

  use Sutra.PrivnetTest

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Cardano.Transaction
  alias Sutra.Data
  alias Sutra.Provider.YaciProvider

  import Sutra.Cardano.Transaction.TxBuilder

  @mint_script_json %{
    "type" => "all",
    "scripts" => [
      %{
        "type" => "after",
        "slot" => 0
      }
    ]
  }

  @mint_script NativeScript.from_json(@mint_script_json)
  @policy_id NativeScript.to_script(@mint_script) |> Script.hash_script()
  @mint_token %{
    Base.encode16("TKN1", case: :lower) => 1,
    Base.encode16("TKN2", case: :lower) => 2
  }

  describe "Simple ADA & Token Test" do
    test "Sending  2 ADA to Random Address" do
      with_default_wallet(5, fn wallet_info ->
        to_address = random_address()

        tx =
          new_tx()
          |> pay_to_address(to_address, Asset.from_lovelace(2_000_000))
          |> build_tx!(wallet_address: [wallet_info.address])

        submit_tx_resp =
          sign_tx(tx, [wallet_info.signing_key])
          |> submit_tx()

        assert submit_tx_resp == Transaction.tx_id(tx)
        await_tx(submit_tx_resp)
        assert YaciProvider.balance_of(to_address) == Asset.from_lovelace(2_000_000)
      end)
    end

    test "Sending Token to random address" do
      with_new_wallet(fn %{address: addr, signing_key: s_key} ->
        recv_addr = random_address()

        tx =
          new_tx()
          |> mint_asset(@policy_id, @mint_token)
          |> pay_to_address(recv_addr, %{@policy_id => @mint_token},
            datum: {:as_hash, Data.encode(58)}
          )
          |> attach_script(@mint_script)
          |> valid_from(System.os_time(:millisecond))
          |> build_tx!(wallet_address: [addr])

        submit_tx_id =
          sign_tx(tx, [s_key])
          |> submit_tx()

        assert submit_tx_id == Transaction.tx_id(tx)
        await_tx(submit_tx_id)

        assert %{@policy_id => @mint_token} ==
                 YaciProvider.balance_of(recv_addr) |> Asset.without_lovelace()
      end)
    end
  end
end
