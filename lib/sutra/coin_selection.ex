defmodule Sutra.CoinSelection do
  @moduledoc """
    asd
  """
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Input

  defstruct [:selected_inputs, :change]

  @type t() :: %__MODULE__{
          selected_inputs: [%Input{}],
          change: Asset.t()
        }

  @spec select_utxos_for_lovelace([Transaction.input()], pos_integer(), Asset.t()) ::
          {:ok, __MODULE__.t()} | {:error, String.t()}
  def select_utxos_for_lovelace(inputs, to_fill_amount, inital_change \\ %{}) do
    to_fill_amount = if to_fill_amount < 0, do: to_fill_amount, else: -to_fill_amount

    {new_used_inputs, change, remaining_fill} =
      sort_by_lovelace(inputs)
      |> Enum.reduce_while({[], inital_change, to_fill_amount}, fn i, {used_inputs, c, r} ->
        current_lovelace = Asset.lovelace_of(i.output.value)

        curr_change = Asset.add(i.output.value, "lovelace", r)

        if current_lovelace + r >= 0,
          do: {:halt, {[i | used_inputs], Asset.merge(c, curr_change), 0}},
          else: {:cont, {[i | used_inputs], c, r + current_lovelace}}
      end)

    if remaining_fill < 0 do
      {:error, "Not enough inputs to fullfill #{remaining_fill} lovelace"}
    else
      {:ok,
       %__MODULE__{
         selected_inputs: new_used_inputs,
         change: Asset.only_positive(change)
       }}
    end
  end

  def sort_by_lovelace(inputs, order \\ :desc),
    do: Enum.sort_by(inputs, fn i -> Asset.lovelace_of(i.output.value) end, order)
end
