defmodule Sutra.Cardano.CoinSelection.LargestFirstTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.CoinSelection
  alias Sutra.CoinSelection.LargestFirst

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

      assert input1.output.value == Asset.from_lovelace(3_000_000)
      assert input2.output.value == %{"lovelace" => 1_000_000, "policy-1" => %{"asset-1" => 1}}
    end
  end

  defp make_input(value, tx_id) when is_map(value) do
    %Input{
      output_reference: %OutputReference{
        transaction_id: tx_id,
        output_index: 0
      },
      output: %Output{value: value}
    }
  end

  defp make_input(lovelace, tx_id), do: Asset.from_lovelace(lovelace) |> make_input(tx_id)
end
