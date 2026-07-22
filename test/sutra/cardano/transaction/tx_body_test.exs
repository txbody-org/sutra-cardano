defmodule Sutra.Cardano.Transaction.TxBodyTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.AccountBalanceInterval
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Data.Cbor

  @addr Address.from_bech32("addr1wxa7ec20249sqg87yu2aqkqp735qa02q6yd93u28gzul93ghspjnt")

  @reward_addr "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"

  @tx_body %TxBody{
    inputs: [
      %OutputReference{
        transaction_id: "bcaeed39733e00db82a5492d5b4791de8dc7e8b4859dafe89ec3915304bd4f4b",
        output_index: 0
      }
    ],
    outputs: [Output.new(@addr, Asset.from_lovelace(2_000_000))],
    fee: Asset.from_lovelace(170_000),
    direct_deposits: %{@reward_addr => Asset.from_lovelace(5_000_000)},
    account_balance_intervals: %{
      %Credential{credential_type: :vkey, hash: @reward_addr} => %AccountBalanceInterval{
        inclusive_lower_bound: 0,
        exclusive_upper_bound: 10_000_000
      }
    }
  }

  describe "direct_deposits (Dijkstra field 25)" do
    test "round trips through to_cbor/1 and decode/1" do
      decoded = @tx_body |> TxBody.to_cbor() |> TxBody.decode()

      assert decoded.direct_deposits == @tx_body.direct_deposits
    end

    test "to_cbor/1 omits key 25 when direct_deposits is nil" do
      refute Map.has_key?(TxBody.to_cbor(%{@tx_body | direct_deposits: nil}), 25)
    end
  end

  describe "account_balance_intervals (Dijkstra field 26)" do
    test "round trips through to_cbor/1 and decode/1" do
      decoded = @tx_body |> TxBody.to_cbor() |> TxBody.decode()

      assert decoded.account_balance_intervals == @tx_body.account_balance_intervals
    end

    test "to_cbor/1 omits key 26 when account_balance_intervals is nil" do
      refute Map.has_key?(TxBody.to_cbor(%{@tx_body | account_balance_intervals: nil}), 26)
    end
  end

  describe "guards (Dijkstra field 14, replaces required_signers)" do
    test "all-vkey guards round trip via the compact addr_keyhash set" do
      guards = [%Credential{credential_type: :vkey, hash: @reward_addr}]
      cbor = TxBody.to_cbor(%{@tx_body | guards: guards})

      assert %CBOR.Tag{tag: 258, value: [%CBOR.Tag{tag: :bytes}]} = cbor[14]
      assert TxBody.decode(cbor).guards == guards
    end

    test "mixed vkey/script guards round trip via the credential oset" do
      guards = [
        %Credential{credential_type: :vkey, hash: @reward_addr},
        %Credential{
          credential_type: :script,
          hash: "a687dcc24e00dd3caafbeb5e68f97ca8ef269cb6fe971345eb951756"
        }
      ]

      cbor = TxBody.to_cbor(%{@tx_body | guards: guards})

      assert %CBOR.Tag{tag: 258, value: [[_, _], [_, _]]} = cbor[14]
      assert TxBody.decode(cbor).guards == guards
    end

    test "decodes a pre-Dijkstra flat required_signers keyhash set into vkey guards" do
      legacy_cbor =
        TxBody.to_cbor(%{@tx_body | guards: nil})
        |> Map.put(
          14,
          [%Credential{credential_type: :vkey, hash: @reward_addr}]
          |> Enum.map(& &1.hash)
          |> Enum.map(&Cbor.as_byte/1)
          |> Cbor.as_nonempty_set()
        )

      assert TxBody.decode(legacy_cbor).guards == [
               %Credential{credential_type: :vkey, hash: @reward_addr}
             ]
    end

    test "to_cbor/1 ignores a required_signers value instead of raising" do
      assert TxBody.to_cbor(%{@tx_body | guards: nil, required_signers: [@reward_addr]}) ==
               TxBody.to_cbor(%{@tx_body | guards: nil, required_signers: nil})
    end
  end
end
