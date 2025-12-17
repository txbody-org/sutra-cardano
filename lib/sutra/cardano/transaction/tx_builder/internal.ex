defmodule Sutra.Cardano.Transaction.TxBuilder.Internal do
  @moduledoc """
    Internal function for Tx Builder
  """

  require Sutra.Cardano.Script

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction.TxBuilder
  alias Sutra.Cardano.Transaction.TxBuilder.Collateral
  alias Sutra.Cardano.Transaction.TxBuilder.Error.ScriptEvaluationFailed
  alias Sutra.Cardano.Transaction.TxBuilder.TxConfig
  alias Sutra.Cardano.Transaction.Witness
  alias Sutra.Cardano.Transaction.Witness.PlutusData
  alias Sutra.Cardano.Transaction.Witness.Redeemer
  alias Sutra.Cardano.Transaction.Witness.VkeyWitness
  alias Sutra.CoinSelection
  alias Sutra.CoinSelection.LargestFirst
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Data.Plutus.PList
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig
  alias Sutra.Uplc
  alias Sutra.Utils

  import Sutra.Utils, only: [maybe: 3]

  @ref_script_size_increment 25_600
  @ref_script_multiplier 1.2

  def process_build_tx(_, [], _), do: {:error, :missing_wallet_utxos}

  def process_build_tx(
        %TxBuilder{} = builder_info,
        [%Input{} | _] = wallet_inputs,
        collateral_inputs
      ) do
    wallet_inputs =
      wallet_inputs -- (collateral_inputs ++ builder_info.ref_inputs)

    sorted_txbuilder = %TxBuilder{
      builder_info
      | inputs: Input.sort_inputs(builder_info.inputs),
        ref_inputs: Input.sort_inputs(builder_info.ref_inputs),
        outputs: alter_outputs_with_min_ada(builder_info)
    }

    sorted_txbuilder
    |> init_txbody(collateral_inputs)
    |> create_tx(builder_info, wallet_inputs, init_witness(sorted_txbuilder))
  end

  defp init_witness(%TxBuilder{} = builder) do
    %Witness{
      redeemer:
        with_mint_redeemers([], builder)
        |> with_cert_redeemers(builder)
        |> with_reward_redeemers(builder),
      script_witness: Map.values(builder.script_lookup) |> Enum.filter(&Script.is_script/1),
      plutus_data: Enum.map(builder.plutus_data, fn {_, v} -> %PlutusData{value: v} end),
      vkey_witness: []
    }
  end

  defp with_mint_redeemers(initial_witness, %TxBuilder{} = tx_builder)
       when map_size(tx_builder.mints) == 0,
       do: initial_witness

  defp with_mint_redeemers(initial_witness, %TxBuilder{
         mints: mint_info,
         redeemer_lookup: redeemer_lookup
       }) do
    sorted_mints = Sutra.Utils.with_sorted_indexed_map(mint_info)

    Enum.reduce(sorted_mints, initial_witness, fn {k, indexed_mint_info}, acc ->
      case Map.get(redeemer_lookup, {:mint, k}) do
        # Witness is from NativeScript Redeemer is not needed
        nil ->
          acc

        redeemer_data ->
          [Witness.init_redeemer(indexed_mint_info[:index], redeemer_data) | acc]
      end
    end)
  end

  defp with_cert_redeemers(initial_witness, %TxBuilder{certificates: certs}) do
    Enum.reduce(Enum.with_index(certs), initial_witness, fn {{_cert, redeemer}, indx}, acc ->
      if is_nil(redeemer), do: acc, else: [Witness.init_redeemer(indx, redeemer, :cert) | acc]
    end)
  end

  defp with_reward_redeemers(initial_witness, %TxBuilder{
         withdrawals: withdrawals,
         redeemer_lookup: redeemer_lookup
       })
       when map_size(redeemer_lookup) > 0 and map_size(withdrawals) > 0 do
    sorted_withdrawls = Sutra.Utils.with_sorted_indexed_map(withdrawals)

    Enum.reduce(sorted_withdrawls, initial_witness, fn {k, indexed_info}, acc ->
      case Map.get(redeemer_lookup, {:reward, k}) do
        nil ->
          acc

        redeemer_data ->
          [Witness.init_redeemer(indexed_info[:index], redeemer_data, :reward) | acc]
      end
    end)
  end

  defp with_reward_redeemers(initial_witness, _), do: initial_witness

  defp with_spend_redeemers(%TxBuilder{} = builder, inputs) do
    Enum.reduce(Enum.with_index(inputs), [], fn {%Input{} = input, indx}, acc ->
      if Address.script_address?(input.output.address) do
        redeemer = %Redeemer{
          index: indx,
          data: Map.get(builder.redeemer_lookup, {:spend, Input.extract_ref(input)}),
          ## placeholder for initial Exunits will be updated later after script Evaluation
          exunits: {0, 0},
          tag: :spend
        }

        [redeemer | acc]
      else
        acc
      end
    end)
  end

  defp total_ref_bytes(inputs, initial \\ 0) when is_list(inputs) do
    Enum.reduce(inputs, initial, fn %Input{output: %Output{} = output}, acc ->
      size =
        if is_binary(output.reference_script), do: byte_size(output.reference_script), else: 0

      acc + size
    end)
  end

  defp calculate_refscript_fee(protocol_params, total_bytes, fee \\ 0)
  defp calculate_refscript_fee(_, 0, fee), do: fee

  defp calculate_refscript_fee(ref_script_cost_per_byte, total_bytes, fee)
       when total_bytes > 0 do
    if total_bytes < @ref_script_size_increment do
      fee + ref_script_cost_per_byte * total_bytes
    else
      new_ref_script_cost = @ref_script_multiplier * ref_script_cost_per_byte

      calculate_refscript_fee(
        new_ref_script_cost,
        total_bytes - @ref_script_size_increment,
        fee + new_ref_script_cost
      )
    end
  end

  defp init_txbody(
         %TxBuilder{
           valid_from: valid_from,
           valid_to: valid_to,
           config: %TxConfig{slot_config: slot_config}
         } = builder,
         collateral_inputs
       ) do
    initial_fee =
      calculate_refscript_fee(
        builder.config.protocol_params.min_fee_ref_script_cost_per_byte,
        total_ref_bytes(builder.ref_inputs)
      ) + 100_000

    ttl =
      maybe(valid_to, nil, &SlotConfig.unix_time_to_slot(&1, slot_config))

    validaty_interval_start =
      maybe(valid_from, nil, &SlotConfig.unix_time_to_slot(&1, slot_config))

    %TxBody{
      inputs: builder.inputs,
      ttl: ttl,
      validaty_interval_start: validaty_interval_start,
      outputs: builder.outputs,
      # Initial fee
      fee: Asset.from_lovelace(floor(initial_fee)),
      mint: builder.mints,
      reference_inputs: builder.ref_inputs,
      # TODO: Handle collateral as list
      collateral: maybe(collateral_inputs, nil, fn i -> [i.output_reference] end),
      total_collateral: maybe(collateral_inputs, nil, fn i -> i.output.value end),
      required_signers: MapSet.to_list(builder.required_signers),
      auxiliary_data_hash:
        maybe(builder.metadata, nil, &(CBOR.encode(&1) |> Blake2b.blake2b_256())),
      script_data_hash: Blake2b.blake2b_256(""),
      certificates: Enum.map(builder.certificates, &Utils.fst/1),
      withdrawals: prepare_withdrawals(builder)
    }
  end

  defp prepare_withdrawals(%TxBuilder{
         config: %TxConfig{change_address: %Address{} = change_address},
         withdrawals: withdrawals,
         script_lookup: script_lookup
       }) do
    network_tag = if change_address.network == :mainnet, do: "1", else: "0"

    Enum.reduce(withdrawals, %{}, fn {k, v}, acc ->
      prefix = if Map.has_key?(script_lookup, k), do: "F", else: "E"
      Map.put(acc, prefix <> network_tag <> k, v)
    end)
  end

  defp create_tx(
         %TxBody{} = tx_body,
         %TxBuilder{config: %TxConfig{protocol_params: protocol_params}} = builder,
         wallet_inputs,
         %Witness{} = witnesses
       ) do
    initial_required_asset = Asset.merge(builder.total_deposit, tx_body.fee)

    with {:ok, %CoinSelection{selected_inputs: selected_inputs} = c_selection} <-
           balance_tx(initial_required_asset, tx_body, wallet_inputs, builder),
         {:ok, %Transaction{tx_body: %TxBody{}, witnesses: %Witness{}} = tx} <-
           derive_tx(tx_body, c_selection, builder, witnesses),
         {:ok, {collateral_refs, collateral_return, collateral_used}} <-
           Collateral.set_collateral(tx, wallet_inputs -- selected_inputs, builder) do
      collateral_retun_output =
        maybe(collateral_return, nil, fn _ ->
          Output.new(builder.config.change_address, collateral_return)
          |> calculate_min_ada_for_output(builder.config.protocol_params)
        end)

      final_tx =
        %Transaction{
          tx
          | tx_body: %TxBody{
              tx.tx_body
              | collateral: collateral_refs,
                collateral_return: collateral_retun_output,
                total_collateral: collateral_used
            },
            witnesses: %Witness{tx.witnesses | vkey_witness: []}
        }

      # Calculate new Tx Fee
      tx_fee = calc_fee(final_tx, protocol_params)

      if Asset.lovelace_of(tx_body.fee) >= tx_fee do
        {:ok, final_tx}
      else
        %TxBody{
          tx_body
          | fee: Asset.from_lovelace(ceil(tx_fee * 1.06)),
            required_signers: final_tx.tx_body.required_signers
        }
        |> create_tx(
          builder,
          wallet_inputs,
          witnesses
        )
      end
    end
  end

  defp derive_tx(
         %TxBody{} = tx_body,
         %CoinSelection{} = selected_coin,
         %TxBuilder{config: %TxConfig{} = cfg} = builder,
         %Witness{} = witness_set
       ) do
    new_inputs =
      (tx_body.inputs ++ selected_coin.selected_inputs)
      |> Input.sort_inputs()

    change_output =
      Output.new(cfg.change_address, Asset.only_positive(selected_coin.change),
        datum: cfg.change_datum
      )
      |> calculate_min_ada_for_output(cfg.protocol_params)

    vkey_witnesses =
      calc_total_signers(builder.required_signers, new_inputs) |> derive_vkey_witness()

    tx = %Transaction{
      tx_body: %TxBody{
        tx_body
        | inputs: new_inputs,
          outputs: tx_body.outputs ++ [change_output]
      },
      witnesses: %Witness{
        witness_set
        | vkey_witness: vkey_witnesses,
          redeemer: witness_set.redeemer ++ with_spend_redeemers(builder, new_inputs)
      },
      is_valid: true,
      metadata: builder.metadata
    }

    with {:ok, redeemers} <- evaluate_uplc(builder, tx) do
      script_data_hash =
        calculate_script_data_hash(
          cfg.protocol_params.cost_models,
          builder.used_scripts,
          Witness.to_cbor(witness_set.plutus_data) |> Map.get(4),
          Witness.to_cbor(redeemers) |> Map.get(5)
        )

      {:ok,
       %Transaction{
         tx
         | witnesses: %Witness{tx.witnesses | redeemer: redeemers},
           tx_body: %TxBody{tx.tx_body | script_data_hash: script_data_hash}
       }}
    end
  end

  defp has_plutus_script?([]), do: false

  defp has_plutus_script?([script_type | rest]) do
    if script_type in [:plutus_v1, :plutus_v2, :plutus_v3],
      do: true,
      else: has_plutus_script?(rest)
  end

  defp evaluate_uplc(
         %TxBuilder{
           config: %TxConfig{
             protocol_params: %ProtocolParams{} = p_params,
             slot_config: %SlotConfig{} = slot_config
           }
         } = builder,
         %Transaction{} = tx
       ) do
    if has_plutus_script?(builder.used_scripts) do
      case Uplc.evaluate(
             tx,
             p_params.cost_models,
             {slot_config.zero_time, slot_config.zero_slot, slot_config.slot_length}
           ) do
        {:ok, redeemers} ->
          {:ok, redeemers}

        {:error, msg} ->
          {:error, ScriptEvaluationFailed.new(msg)}
      end
    else
      {:ok, []}
    end
  end

  defp alter_outputs_with_min_ada(
         %TxBuilder{config: %TxConfig{protocol_params: protocol_params}} = builder
       ) do
    Enum.map(builder.outputs, &calculate_min_ada_for_output(&1, protocol_params))
  end

  defp calculate_min_ada_for_output(%Output{} = output, %ProtocolParams{} = params) do
    byte_length = output |> Output.to_cbor() |> CBOR.encode() |> byte_size()
    min_fee = ceil(params.ada_per_utxo_byte * (byte_length + 160))

    if Asset.lovelace_of(output.value) >= min_fee do
      output
    else
      %Output{
        output
        | value: Asset.without_lovelace(output.value) |> Asset.add("lovelace", min_fee)
      }
      |> calculate_min_ada_for_output(params)
    end
  end

  defp calc_total_signers(%MapSet{} = required_signers, used_inputs) when is_list(used_inputs) do
    Enum.reduce(used_inputs, required_signers, fn %Input{output: output}, acc ->
      if Address.vkey_address?(output.address),
        do: MapSet.put(acc, output.address.payment_credential.hash),
        else: acc
    end)
  end

  defp derive_vkey_witness(%MapSet{} = signers) do
    signers
    |> MapSet.to_list()
    |> Enum.map(fn hash ->
      %VkeyWitness{vkey: hash, signature: Base.encode16(<<0::size(512)>>)}
    end)
  end

  defp calc_fee(
         %Transaction{} = tx,
         %ProtocolParams{
           execution_costs: %ExecutionUnitPrice{
             step_price: {step_price_n, step_price_d},
             mem_price: {mem_price_n, mem_price_d}
           }
         } = protocol_params
       ) do
    cost_per_step = step_price_n / step_price_d
    cost_per_mem = mem_price_n / mem_price_d

    tx_cbor = Transaction.to_cbor(tx) |> CBOR.encode()
    fee = protocol_params.min_fee_A * byte_size(tx_cbor) + protocol_params.min_fee_B

    Enum.reduce(tx.witnesses.redeemer, fee, fn %Redeemer{exunits: {mem, cpu}}, acc ->
      acc + cost_per_mem * mem + cost_per_step * cpu
    end)
  end

  defp balance_tx(
         initial_asset_to_cover,
         %TxBody{} = tx_body,
         [%Input{} | _] = wallet_inputs,
         %TxBuilder{} = builder
       ) do
    {to_fill_asset, leftover_asset} = calculate_assets_flow(tx_body, initial_asset_to_cover)
    available_inputs = wallet_inputs -- tx_body.inputs

    with {:ok, selection} <-
           initial_selection(available_inputs, to_fill_asset, leftover_asset) do
      ensure_min_ada_for_change(selection, available_inputs, builder)
    end
  end

  defp calculate_assets_flow(tx_body, initial_asset_to_cover) do
    total_with_mint =
      Enum.reduce(tx_body.inputs, tx_body.mint, fn i, acc ->
        Asset.merge(i.output.value, acc)
      end)

    total_output_assets =
      Enum.reduce(tx_body.outputs, initial_asset_to_cover, fn o, acc ->
        Asset.merge(o.value, acc)
      end)

    to_fill = Asset.diff(total_with_mint, total_output_assets) |> Asset.only_positive()
    leftover = Asset.diff(total_output_assets, total_with_mint) |> Asset.only_positive()

    {to_fill, leftover}
  end

  defp initial_selection(inputs, to_fill, leftover) do
    if Asset.zero() != to_fill do
      LargestFirst.select_utxos(inputs, to_fill, leftover)
    else
      {:ok, %CoinSelection{selected_inputs: [], change: leftover}}
    end
  end

  defp ensure_min_ada_for_change(selection, available_inputs, builder) do
    change_output_template = Output.new(builder.config.change_address, selection.change)

    min_ada_output =
      calculate_min_ada_for_output(change_output_template, builder.config.protocol_params)

    min_ada_required = Asset.lovelace_of(min_ada_output.value)
    current_change_lovelace = Asset.lovelace_of(selection.change)

    if current_change_lovelace >= min_ada_required do
      {:ok, selection}
    else
      needed = min_ada_required - current_change_lovelace
      remaining_inputs = available_inputs -- selection.selected_inputs

      CoinSelection.select_utxos_for_lovelace(remaining_inputs, needed, selection.change)
      |> Utils.when_ok(fn extra ->
        {:ok,
         %CoinSelection{
           selected_inputs: selection.selected_inputs ++ extra.selected_inputs,
           change: extra.change
         }}
      end)
    end
  end

  # If transaction includes datums but does not
  # include the redeemers field, the script data format becomes (in hex):
  # [ A0 | datums | A0 ]
  defp calculate_script_data_hash(_cost_models, _script_lookup, datums, nil)
       when not is_nil(datums) do
    ("\xA0" <> CBOR.encode(datums) <> "\xA0")
    |> Blake2b.blake2b_256()
  end

  # Calculate Script Data Hash
  defp calculate_script_data_hash(%CostModels{} = cost_model, used_scripts, datums, redeemer)
       when is_map(redeemer) and redeemer != %{} do
    lang_views =
      Enum.reduce(used_scripts, %{}, fn script_type, acc ->
        cond do
          script_type == :plutus_v1 ->
            # The language ID tag for Plutus V1 is encoded twice. first as a uint then as
            # a bytestring.
            # Concretely, this means that the language version for V1 is encoded as
            # 4100 in hex.
            #
            # The value of cost_models map for v1
            # is encoded as an indefinite length list and the result is encoded as a bytestring.
            # Therefore using %PList{} instead of normal list
            Map.put_new(acc, 0x4100, %PList{value: cost_model.plutus_v1})

          script_type == :plutus_v2 ->
            Map.put_new(acc, 1, cost_model.plutus_v2)

          script_type == :plutus_v3 ->
            Map.put_new(acc, 2, cost_model.plutus_v3)

          true ->
            acc
        end
      end)

    (CBOR.encode(redeemer) <>
       Utils.maybe(datums, "", &CBOR.encode/1) <> CBOR.encode(lang_views))
    |> Blake2b.blake2b_256()
  end

  defp calculate_script_data_hash(_, _, _, _), do: nil
end
