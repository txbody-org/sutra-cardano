defmodule Sutra.CoinSelection.LargestFirst do
  @moduledoc """
    LargestFirst Coinselection algorithm
  """
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.{Input, Output}
  alias Sutra.CoinSelection

  @doc """
  Selects Utxos based on LargestFirst CoinSelection Algorithm
  """
  @spec select_utxos([Transaction.input()], Asset.t()) ::
          {:ok, CoinSelection.t()} | {:error, String.t()}
  def select_utxos(_, %{} = asset) when map_size(asset) == 0,
    do: {:ok, %CoinSelection{selected_inputs: [], change: %{}}}

  def select_utxos(inputs, %{"lovelace" => lovelace_amt} = asset) when map_size(asset) == 1,
    do: CoinSelection.select_utxos_for_lovelace(inputs, lovelace_amt)

  def select_utxos(inputs, to_fill_asset) do
    sorted_inputs = CoinSelection.sort_by_lovelace(inputs)

    initial_state = {[], %{}, Asset.negate(to_fill_asset)}

    {used_inputs, change, remaining_to_fill} =
      Enum.reduce_while(sorted_inputs, initial_state, &do_calc_change_asset/2)

    cond do
      remaining_to_fill == %{} ->
        {:ok,
         %CoinSelection{
           selected_inputs: used_inputs,
           change: Asset.only_positive(change)
         }}

      Asset.policies(remaining_to_fill) != [] ->
        {:error, "No inputs available to full assets"}

      # Need to balance remaining lovelace
      # TODO: Make this function better
      true ->
        remaining_inputs = sorted_inputs -- used_inputs
        remaing_lovelace = Asset.lovelace_of(remaining_to_fill)

        with {:ok, %CoinSelection{selected_inputs: sel_inputs} = new_selection} <-
               CoinSelection.select_utxos_for_lovelace(remaining_inputs, remaing_lovelace, change) do
          {:ok,
           %CoinSelection{
             new_selection
             | selected_inputs: sel_inputs ++ used_inputs
           }}
        end
    end
  end

  defp do_calc_change_asset(_, {used_inputs, change, to_fill}) when to_fill == %{},
    do: {:halt, {used_inputs, change, to_fill}}

  defp do_calc_change_asset(
         %Input{output: %Output{} = output} = input,
         {used_inputs, change, to_fill}
       ) do
    input_assets = output.value
    current_lovelace_value = Asset.lovelace_of(input_assets)

    remaining_asset_to_fill = Asset.filter_by_value(to_fill, &(&1 < 0))
    remaining_asset_lovelace = Asset.lovelace_of(remaining_asset_to_fill)

    cond do
      # only lovelace is left to fill
      Asset.policies(remaining_asset_to_fill) == [] and
          remaining_asset_lovelace + current_lovelace_value >= 0 ->
        curr_change = Asset.add(input_assets, "lovelace", -remaining_asset_lovelace)

        {:halt,
         {[input | used_inputs],
          Asset.merge(
            change,
            curr_change
          ), %{}}}

      Asset.contains_token?(input_assets, remaining_asset_to_fill) ->
        {new_change, new_to_fill} = use_input(input_assets, change, to_fill)
        {:cont, {[input | used_inputs], new_change, new_to_fill}}

      true ->
        {:cont, {used_inputs, change, to_fill}}
    end
  end

  defp use_input(current_value, change_value, to_fill_value) do
    used_value = Asset.merge(to_fill_value, current_value)

    new_change_value =
      Asset.only_positive(used_value) |> Asset.merge(change_value) |> Asset.only_positive()

    {new_change_value, Asset.filter_by_value(used_value, &(&1 < 0))}
  end
end
