defmodule Sutra.Cardano.Transaction.TxBuilder.Collateral do
  @moduledoc false

  alias Sutra.Cardano.Transaction.TxBuilder.Error.NoSuitableCollateralUTXO
  alias Sutra.CoinSelection
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.TxBuilder.TxConfig
  alias Sutra.Cardano.Transaction.TxBuilder
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction.Witness
  alias Sutra.Cardano.Transaction

  # Calculates required collateral amount
  defp calc_total_collateral_fee(_cfg, _tx) do
    5_000_000
  end

  @doc false
  def set_collateral(
        %Transaction{witnesses: %Witness{redeemer: redeemer}},
        _wallet_inputs,
        _cfg
      )
      when redeemer == [] or is_nil(redeemer) do
    {:ok, {nil, nil, nil}}
  end

  def set_collateral(
        %Transaction{tx_body: %TxBody{collateral: nil}} = tx,
        wallet_inputs,
        %TxBuilder{config: %TxConfig{} = config}
      )
      when is_list(wallet_inputs) do
    collateral_fee = calc_total_collateral_fee(config, tx)

    case CoinSelection.select_utxos_for_lovelace(wallet_inputs, collateral_fee) do
      {:ok, %CoinSelection{selected_inputs: collateral_inputs, change: change}}
      when change == %{} ->
        {:ok,
         {Enum.map(collateral_inputs, & &1.output_reference), nil,
          Asset.from_lovelace(collateral_fee)}}

      {:ok,
       %CoinSelection{
         selected_inputs: collateral_inputs,
         change: %{"lovelace" => lovelace_val} = change
       }}
      when lovelace_val >= 1_000_000 ->
        {:ok,
         {Enum.map(collateral_inputs, & &1.output_reference), change,
          Asset.from_lovelace(collateral_fee)}}

      {:ok, %CoinSelection{selected_inputs: collateral_inputs}} ->
        used_collateral =
          Enum.reduce(collateral_inputs, Asset.zero(), fn i, acc ->
            Asset.merge(i.output.value, acc)
          end)

        {:ok, {Enum.map(collateral_inputs, & &1.output_reference), nil, used_collateral}}

      _ ->
        {:error, NoSuitableCollateralUTXO.new(tx, collateral_fee)}
    end
  end
end
