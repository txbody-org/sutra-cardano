defmodule Sutra.CoinSelection.LargestFirst do
  @moduledoc """
    LargestFirst CoinSelection algorithm.

    Strategies:
    1. Native Tokens: For each required token, select inputs containing that token,
       sorted by the token amount (descending).
    2. Lovelace: After satisfying native tokens, if more Lovelace is needed,
       select inputs sorted by Lovelace amount (descending).
  """

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.TxBuilder.Error
  alias Sutra.CoinSelection

  @doc """
  Selects Utxos based on LargestFirst CoinSelection Algorithm
  """
  @spec select_utxos([Transaction.input()], Asset.t(), Asset.t()) ::
          {:ok, CoinSelection.t()} | {:error, String.t()}

  def select_utxos(inputs, to_fill, left_over \\ %{})

  def select_utxos(_, %{} = to_fill, left_over) when map_size(to_fill) == 0,
    do: {:ok, %CoinSelection{selected_inputs: [], change: left_over}}

  def select_utxos(inputs, to_fill, left_over) do
    # 1. Phase 1: Select for Native Tokens
    with {:ok, selected_inputs, remaining_inputs, current_value} <-
           select_native_tokens(inputs, to_fill) do
      # 2. Phase 2: Select for Lovelace
      target_lovelace = Asset.lovelace_of(to_fill)
      current_lovelace = Asset.lovelace_of(current_value)
      needed_lovelace = target_lovelace - current_lovelace

      if needed_lovelace > 0 do
        case CoinSelection.select_utxos_for_lovelace(
               remaining_inputs,
               needed_lovelace,
               %{}
             ) do
          {:ok, %CoinSelection{selected_inputs: lovelace_inputs}} ->
            final_inputs = selected_inputs ++ lovelace_inputs
            final_value = sum_values(final_inputs)
            calculate_result(final_inputs, final_value, to_fill, left_over)

          {:error, _} ->
            # Construct error with missing lovelace
            {:error, Error.CannotBalanceTx.new(%{"lovelace" => needed_lovelace})}
        end
      else
        calculate_result(selected_inputs, current_value, to_fill, left_over)
      end
    end
  end

  defp calculate_result(selected_inputs, current_value, to_fill, left_over) do
    # Change = (Current - Target) + LeftOver
    # We use Asset.negate(to_fill) to subtract target
    surplus = Asset.merge(current_value, Asset.negate(to_fill))
    change = Asset.merge(surplus, left_over)

    {:ok,
     %CoinSelection{
       selected_inputs: selected_inputs,
       change: Asset.only_positive(change)
     }}
  end

  defp select_native_tokens(inputs, to_fill) do
    requirements = flatten_requirements(to_fill)

    # Iterate over requirements and accumulate selection
    result =
      Enum.reduce_while(
        requirements,
        {[], inputs, %{}},
        &process_token_requirement/2
      )

    case result do
      {:error, missing} -> {:error, Error.CannotBalanceTx.new(missing)}
      {selected, available, current_val} -> {:ok, selected, available, current_val}
    end
  end

  defp process_token_requirement(
         {policy, name, target_amount},
         {selected, available, current_val}
       ) do
    current_amount = get_quantity(current_val, policy, name)

    if current_amount >= target_amount do
      {:cont, {selected, available, current_val}}
    else
      select_more_tokens(
        policy,
        name,
        target_amount,
        current_amount,
        selected,
        available,
        current_val
      )
    end
  end

  defp select_more_tokens(
         policy,
         name,
         target_amount,
         current_amount,
         selected,
         available,
         current_val
       ) do
    needed = target_amount - current_amount

    # Filter and sort available inputs for this token
    candidates =
      available
      |> Enum.filter(fn input ->
        get_quantity(input.output.value, policy, name) > 0
      end)
      |> Enum.sort_by(
        fn input -> get_quantity(input.output.value, policy, name) end,
        :desc
      )

    # Select inputs until satisfied
    {newly_selected, _remaining_candidates, new_val, satisfied} =
      select_until_satisfied(candidates, policy, name, needed, current_val)

    if satisfied do
      # Update available inputs: remove newly selected
      new_available = available -- newly_selected
      {:cont, {selected ++ newly_selected, new_available, new_val}}
    else
      # Failed to satisfy a token requirement
      missing_amount = target_amount - get_quantity(new_val, policy, name)
      {:halt, {:error, %{policy => %{name => missing_amount}}}}
    end
  end

  defp select_until_satisfied(candidates, policy, name, needed, current_val) do
    Enum.reduce_while(
      candidates,
      {[], current_val, needed},
      fn input, {sel, val, current_needed} ->
        input_qty = get_quantity(input.output.value, policy, name)
        new_val = Asset.merge(val, input.output.value)
        new_sel = [input | sel]

        new_needed = current_needed - input_qty

        if new_needed <= 0 do
          {:halt, {new_sel, new_val, true}}
        else
          {:cont, {new_sel, new_val, new_needed}}
        end
      end
    )
    |> case do
      {sel, val, true} -> {Enum.reverse(sel), [], val, true}
      {sel, val, _} -> {Enum.reverse(sel), [], val, false}
    end
  end

  defp flatten_requirements(assets) do
    Enum.reduce(assets, [], &flatten_policy_requirements/2)
  end

  defp flatten_policy_requirements({"lovelace", _}, acc), do: acc

  defp flatten_policy_requirements({policy, tokens}, acc) do
    Enum.reduce(tokens, acc, fn {name, amount}, inner_acc ->
      if amount > 0, do: [{policy, name, amount} | inner_acc], else: inner_acc
    end)
  end

  defp get_quantity(asset, "lovelace", _), do: Asset.lovelace_of(asset)

  defp get_quantity(asset, policy, name) do
    get_in(asset, [policy, name]) || 0
  end

  defp sum_values(inputs) do
    Enum.reduce(inputs, %{}, fn input, acc ->
      Asset.merge(acc, input.output.value)
    end)
  end
end
