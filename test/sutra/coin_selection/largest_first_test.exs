defmodule Sutra.CoinSelection.LargestFirstTest do
  @moduledoc false

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.CoinSelection
  alias Sutra.CoinSelection.LargestFirst

  use ExUnit.Case, async: true

  describe "LargestFirst with Lovelace" do
    test "returns selected inputs with correct change" do
      inputs =
        [
          make_input(1_000_000, "tx-id-1"),
          make_input(3_000_000, "tx-id-3"),
          make_input(3_000_000, "tx-id-2")
        ]

      to_fill = Asset.from_lovelace(4_000_000)

      assert {:ok,
              %CoinSelection{
                selected_inputs: [input1, input2],
                change: %{"lovelace" => 2_000_000}
              }} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert input1.output.value == Asset.from_lovelace(3_000_000)
      assert input2.output.value == Asset.from_lovelace(3_000_000)
    end

    test "returns selected inputs with 0 change" do
      inputs =
        [
          make_input(1_000_000, "tx-id-1"),
          make_input(3_000_000, "tx-id-3"),
          make_input(3_000_000, "tx-id-2")
        ]

      to_fill = Asset.from_lovelace(7_000_000)

      assert {:ok, %CoinSelection{selected_inputs: [input1, input2, input3], change: change}} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert Asset.only_positive(change) == %{}
      assert input1.output.value == Asset.from_lovelace(1_000_000)
      assert input2.output.value == Asset.from_lovelace(3_000_000)
      assert input3.output.value == Asset.from_lovelace(3_000_000)
    end

    test "returns corect inputs and change for multi Asset input" do
      inputs =
        [
          make_input(%{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 1}}, "tx-id-1"),
          make_input(3_000_000, "tx-id-3"),
          make_input(3_000_000, "tx-id-2")
        ]

      to_fill = Asset.from_lovelace(7_000_000)

      assert {:ok,
              %CoinSelection{
                selected_inputs: sel_inputs,
                change: %{"policy-1" => %{"asset-1" => 1}}
              }} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert [input1, input2, input3] = sel_inputs

      assert input1.output.value == %{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 1}}
      assert input2.output.value == Asset.from_lovelace(3_000_000)
      assert input3.output.value == Asset.from_lovelace(3_000_000)
    end

    test "returns error if not enough inputs available" do
      inputs =
        [
          make_input(%{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 1}}, "tx-id-1"),
          make_input(3_000_000, "tx-id-3"),
          make_input(3_000_000, "tx-id-2")
        ]

      to_fill = Asset.from_lovelace(8_000_000)

      assert {:error, _} =
               LargestFirst.select_utxos(inputs, to_fill)
    end
  end

  describe "LargestFirst coinselection for multi Asset output" do
    test "returns valid change with multi asset output asset" do
      inputs =
        [
          make_input(%{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 1}}, "tx-id-1"),
          make_input(3_000_000, "tx-id-3"),
          make_input(3_000_000, "tx-id-2")
        ]

      to_fill = Asset.from_lovelace(4_000_000) |> Asset.add("policy-1", "asset-1", 1)

      assert {:ok,
              %CoinSelection{
                selected_inputs: sel_inputs,
                change: change
              }} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert [input1, input2] = sel_inputs
      assert change == %{}

      assert input1.output.value == %{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 1}}
      assert input2.output.value == Asset.from_lovelace(3_000_000)
    end

    test "selects additional lovelace inputs when token inputs are insufficient for lovelace" do
      inputs =
        [
          make_input(%{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 10}}, "tx-token"),
          make_input(5_000_000, "tx-ada-1"),
          make_input(2_000_000, "tx-ada-2")
        ]

      # Need 10 tokens and 4 ADA. Token UTxO has 1 ADA. Need 3 more ADA.
      # Should pick tx-token (1 ADA) + tx-ada-1 (5 ADA) = 6 ADA. Change 2 ADA.
      to_fill = Asset.from_lovelace(4_000_000) |> Asset.add("policy-1", "asset-1", 10)

      assert {:ok, %CoinSelection{selected_inputs: sel_inputs, change: change}} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert length(sel_inputs) == 2
      # First should be token input (phase 1)
      assert Enum.any?(sel_inputs, fn i -> i.output_reference.transaction_id == "tx-token" end)
      # Second should be largest ADA input (phase 2)
      assert Enum.any?(sel_inputs, fn i -> i.output_reference.transaction_id == "tx-ada-1" end)

      assert change == %{"lovelace" => 2_000_000}
    end

    test "selects multiple inputs for single token requirement (largest first)" do
      inputs =
        [
          make_input(%{"lovelace" => 2_000_000, "policy-1" => %{"asset-1" => 10}}, "tx-small"),
          make_input(%{"lovelace" => 2_000_000, "policy-1" => %{"asset-1" => 50}}, "tx-large"),
          make_input(%{"lovelace" => 2_000_000, "policy-1" => %{"asset-1" => 20}}, "tx-medium")
        ]

      # Need 60 tokens. Should pick tx-large (50) then tx-medium (20).
      to_fill = Asset.from_lovelace(2_000_000) |> Asset.add("policy-1", "asset-1", 60)

      assert {:ok, %CoinSelection{selected_inputs: sel_inputs}} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert length(sel_inputs) == 2
      [first, second] = sel_inputs
      assert first.output_reference.transaction_id == "tx-large"
      assert second.output_reference.transaction_id == "tx-medium"
    end

    test "handles multiple different tokens" do
      inputs =
        [
          make_input(%{"lovelace" => 2_000_000, "p1" => %{"t1" => 10}}, "tx-1"),
          make_input(%{"lovelace" => 2_000_000, "p2" => %{"t2" => 20}}, "tx-2"),
          make_input(5_000_000, "tx-ada")
        ]

      to_fill =
        Asset.from_lovelace(2_000_000)
        |> Asset.add("p1", "t1", 5)
        |> Asset.add("p2", "t2", 5)

      assert {:ok, %CoinSelection{selected_inputs: sel_inputs}} =
               LargestFirst.select_utxos(inputs, to_fill)

      # Should pick tx-1 and tx-2. Order depends on map iteration of requirements,
      # but both must be present.
      assert length(sel_inputs) == 2
      ids = Enum.map(sel_inputs, & &1.output_reference.transaction_id)
      assert "tx-1" in ids
      assert "tx-2" in ids
    end

    test "returns error when specific token is missing" do
      inputs = [make_input(5_000_000, "tx-ada")]
      to_fill = Asset.from_lovelace(2_000_000) |> Asset.add("p1", "t1", 1)

      assert {:error, error} = LargestFirst.select_utxos(inputs, to_fill)
      # Error should mention missing token
      assert inspect(error) =~ "p1"
    end

    test "handles exact match for token amount" do
      inputs = [
        make_input(%{"lovelace" => 2_000_000, "p1" => %{"t1" => 10}}, "tx-exact"),
        make_input(%{"lovelace" => 2_000_000, "p1" => %{"t1" => 20}}, "tx-larger")
      ]

      # Need exactly 10. Should pick tx-larger because it's largest first?
      # Wait, Largest First sorts candidates descending.
      # So it will pick tx-larger (20) first, satisfy the 10, and have 10 change.
      # It does NOT look for exact match first.

      to_fill = Asset.from_lovelace(1_000_000) |> Asset.add("p1", "t1", 10)

      assert {:ok, %CoinSelection{selected_inputs: [selected], change: change}} =
               LargestFirst.select_utxos(inputs, to_fill)

      assert selected.output_reference.transaction_id == "tx-larger"
      assert change["p1"]["t1"] == 10
    end
  end

  defp make_input(value, tx_id) when is_map(value) do
    %Input{
      output_reference: %OutputReference{
        transaction_id: tx_id,
        output_index: 0
      },
      output: %Output{
        value: value,
        address: dummy_address(),
        datum: dummy_datum()
      }
    }
  end

  defp make_input(lovelace, tx_id), do: Asset.from_lovelace(lovelace) |> make_input(tx_id)

  defp dummy_address do
    %Sutra.Cardano.Address{
      address_type: :shelley,
      network: :testnet,
      payment_credential: %Sutra.Cardano.Address.Credential{
        credential_type: :vkey,
        hash: "0b8418cb378671165f749b4c0de768e703ff4834f216ccc1aa54c561"
      },
      stake_credential: nil
    }
  end

  defp dummy_datum do
    %Sutra.Cardano.Transaction.Datum{kind: :no_datum, value: nil}
  end
end
