defmodule Sutra.Cardano.Transaction.TxBuilder.Internal do
  @moduledoc """
    Internal Helper function for Transaction builder
  """

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.{Input, Output, OutputReference, TxBody, TxBuilder, Witness}
  alias Sutra.Cardano.Transaction.TxBuilder.Error.NoScriptWitness
  alias Sutra.Cardano.Transaction.TxBuilder.Error.NoSuitableCollateralUTXO
  alias Sutra.Cardano.Transaction.TxBuilder.Error.ScriptEvaluationFailed
  alias Sutra.CoinSelection
  alias Sutra.CoinSelection.LargestFirst
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Data.Plutus.PList
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig
  alias Sutra.Uplc
  alias Sutra.Utils
  alias TxBuilder.TxConfig
  alias Witness.{PlutusData, Redeemer, VkeyWitness}

  import Sutra.Utils, only: [maybe: 3]

  @ref_script_size_increment 25_600
  @ref_script_multiplier 1.2

  @spec extract_ref(Transaction.input() | OutputReference.t()) :: String.t()
  def extract_ref(%Input{} = input),
    do: extract_ref(input.output_reference)

  def extract_ref(%OutputReference{transaction_id: tx_id, output_index: indx}),
    do: "#{tx_id}##{indx}"

  defp total_ref_bytes(inputs, initial \\ 0) when is_list(inputs) do
    Enum.reduce(inputs, initial, fn %Input{output: %Output{} = output}, acc ->
      size =
        if is_binary(output.reference_script), do: byte_size(output.reference_script), else: 0

      acc + size
    end)
  end

  def finalize_tx(wallet_utxos, %TxBuilder{} = builder, collateral_ref) do
    wallet_utxos =
      wallet_utxos
      |> Enum.filter(&is_nil(&1.output.reference_script))
      |> then(fn utxos -> utxos -- builder.ref_inputs end)

    # Remove Inputs from wallet if collateral is passed
    {new_wallet_inputs, collateral_input} =
      maybe(collateral_ref, {wallet_utxos, nil}, fn _ ->
        Utils.without_elem(wallet_utxos, fn i ->
          i.output_reference == collateral_ref
        end)
      end)

    # Maybe we don't need to do this here?
    builder = %TxBuilder{
      alter_outputs_with_min_ada(builder)
      | inputs: Enum.sort_by(builder.inputs, &extract_ref/1),
        collateral_input: collateral_input
    }

    inital_ref_script_size = total_ref_bytes(builder.ref_inputs ++ builder.inputs)

    initial_fee =
      calculate_refscript_fee(
        builder.config.protocol_params.min_fee_ref_script_cost_per_byte,
        inital_ref_script_size
      ) + 100_000

    reference_script_lookup =
      Enum.with_index(builder.ref_inputs, 0)
      |> Enum.reduce(%{}, fn {%Input{output: %Output{} = o}, indx}, acc ->
        if Script.script?(o.reference_script) do
          Map.put(acc, Script.hash_script(o.reference_script), indx)
        else
          acc
        end
      end)

    # Initialize TxBody with default values
    draft_txbody = create_draft_txbody(builder, collateral_input, initial_fee)

    with {:ok, %Witness{} = witness} <- with_initial_witness(builder, reference_script_lookup),
         {:ok, %Transaction{witnesses: w} = tx} <-
           create_tx(draft_txbody, builder, new_wallet_inputs, witness) do
      {:ok,
       %Transaction{
         tx
         | witnesses: %Witness{w | vkey_witness: []},
           is_valid: true,
           metadata: builder.metadata
       }}
    end
  end

  defp with_initial_witness(%TxBuilder{} = builder, ref_script_lookup) do
    with {:ok, mint_redeemers} <- with_mint_redeemer(builder, ref_script_lookup) do
      {:ok,
       %Witness{
         script_witness: with_script_witness(builder.scripts_lookup),
         plutus_data: Enum.map(builder.plutus_data, fn d -> %PlutusData{value: d} end),
         redeemer: mint_redeemers,
         vkey_witness: []
       }}
    end
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

  defp with_collateral(%Transaction{} = tx, wallet_utxos, _confg)
       when tx.witnesses.redeemer == [] or is_nil(tx.witnesses.redeemer) do
    new_tx =
      %Transaction{
        tx
        | tx_body: %TxBody{tx.tx_body | collateral_return: nil, collateral: nil}
      }

    {:ok, {new_tx, wallet_utxos -- tx.tx_body.inputs}}
  end

  defp with_collateral(
         %Transaction{tx_body: %TxBody{collateral: nil}} = tx,
         wallet_utxos,
         %TxBuilder{config: %TxConfig{} = config}
       )
       when is_list(wallet_utxos) do
    available_utxos = wallet_utxos -- tx.tx_body.inputs
    # TODO calculate collateral Fee  using TX
    collateral_fee = 5_000_000

    sorted_by_val =
      Enum.sort_by(available_utxos, fn %Input{output: %Output{value: val}} ->
        Asset.lovelace_of(val)
      end)

    fetch_collateral_combined = fn ->
      Enum.reduce_while(sorted_by_val, {[], collateral_fee}, fn %Input{output: output} = input,
                                                                {inputs, amt_left} ->
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if amt_left <= 0,
          do: {:halt, inputs},
          else: {:cont, {[input | inputs], amt_left - Asset.lovelace_of(output.value)}}
      end)
    end

    set_collateral = fn inputs ->
      {total_asset_used, collateral_refs} =
        Enum.reduce(inputs, {Asset.zero(), []}, fn i, {used_asset, refs} ->
          {Asset.merge(used_asset, i.output.value), [i.output_reference | refs]}
        end)

      change = Asset.add(total_asset_used, "lovelace", -collateral_fee)

      collateral_retun =
        if Asset.is_positive_asset(change),
          do: Output.new(config.change_address, change),
          else: nil

      %Transaction{
        tx
        | tx_body: %TxBody{
            tx.tx_body
            | collateral: collateral_refs,
              collateral_return: collateral_retun,
              total_collateral: Asset.from_lovelace(collateral_fee)
          }
      }
    end

    # TODO: check collateral exceedes total count
    collateral_inputs =
      sorted_by_val
      |> Enum.find(fn i -> Asset.lovelace_of(i.output.value) >= collateral_fee end)
      |> Utils.maybe(fetch_collateral_combined, fn i -> [i] end)

    if is_list(collateral_inputs) and collateral_inputs != [] do
      {:ok, {set_collateral.(collateral_inputs), available_utxos -- collateral_inputs}}
    else
      {:error, NoSuitableCollateralUTXO.new(tx, collateral_fee)}
    end
  end

  defp with_collateral(%Transaction{} = tx, wallet_utxos, _),
    do: {:ok, {tx, wallet_utxos -- tx.tx_body.inputs}}

  defp with_script_witness(%{
         native: native_scripts,
         plutus_v1: plutus_v1_scripts,
         plutus_v2: plutus_v2_scripts,
         plutus_v3: plutus_v3_scripts
       }) do
    all_witnesses =
      Map.values(native_scripts) ++
        Map.values(plutus_v1_scripts) ++
        Map.values(plutus_v2_scripts) ++ Map.values(plutus_v3_scripts)

    Enum.filter(all_witnesses, &Script.script?/1)
  end

  ## FIXME:  Return eror if no redeemer is found
  defp with_spend_redeemers(%TxBuilder{} = builder, inputs) do
    Enum.reduce(Enum.with_index(inputs), [], fn {%Input{} = input, indx}, acc ->
      if Address.script_address?(input.output.address) do
        redeemer = %Redeemer{
          index: indx,
          data: Map.get(builder.redeemer_lookup, {:spend, extract_ref(input)}),
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

  defp with_mint_redeemer(
         %TxBuilder{
           scripts_lookup: %{
             native: native_script_lookup,
             plutus_v1: v1,
             plutus_v2: v2,
             plutus_v3: v3
           }
         } = builder,
         ref_script_lookup
       )
       when map_size(builder.mints) > 0 do
    [indexed_v1, indexed_v2, indexed_v3] =
      [v1, v2, v3]
      |> Enum.map(&Utils.with_sorted_indexed_map/1)

    mint_redeemers =
      Enum.reduce_while(builder.mints, [], fn {k, _}, acc ->
        key = {:mint, k}
        redeemer_data = Map.get(builder.redeemer_lookup, key)

        cond do
          Map.get(native_script_lookup, k) ->
            {:cont, acc}

          Map.get(ref_script_lookup, k) ->
            {:cont, [Witness.init_redeemer(ref_script_lookup[k], redeemer_data) | acc]}

          is_nil(redeemer_data) ->
            {:halt, {:error, "Redeemer Missing for Mint, PolicyId: #{k}"}}

          Map.get(indexed_v1, k) ->
            {:cont, [Witness.init_redeemer(indexed_v1[k].index, redeemer_data) | acc]}

          Map.get(indexed_v2, k) ->
            {:cont, [Witness.init_redeemer(indexed_v2[k].index, redeemer_data) | acc]}

          Map.get(indexed_v3, k) ->
            {:cont, [Witness.init_redeemer(indexed_v3[k].index, redeemer_data) | acc]}

          true ->
            {:halt, {:error, NoScriptWitness.new(k)}}
        end
      end)

    Utils.ok_or_error(mint_redeemers)
  end

  defp with_mint_redeemer(_, _), do: {:ok, []}

  defp create_draft_txbody(
         %TxBuilder{
           config: %TxConfig{slot_config: slot_config},
           valid_to: valid_to,
           valid_from: valid_from
         } =
           builder,
         collateral_input,
         fee
       ) do
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
      fee: Asset.from_lovelace(floor(fee)),
      mint: builder.mints,
      reference_inputs: builder.ref_inputs,
      collateral: maybe(collateral_input, nil, fn i -> [i.output_reference] end),
      total_collateral: maybe(collateral_input, nil, fn i -> i.output.value end),
      required_signers: MapSet.to_list(builder.required_signers),
      # TODO: use proper Auxiliary Data format
      auxiliary_data_hash: set_auxiliary_data_hash(builder.metadata),
      script_data_hash: Blake2b.blake2b_256("")
    }
  end

  defp set_auxiliary_data_hash(nil), do: nil

  defp set_auxiliary_data_hash(metadata) do
    metadata
    |> CBOR.encode()
    |> Blake2b.blake2b_256()
  end

  defp derive_tx(
         %TxBody{} = tx_body,
         %CoinSelection{} = selected_coin,
         %TxBuilder{config: %TxConfig{} = cfg} = builder,
         %Witness{} = witness_set
       ) do
    new_inputs =
      (tx_body.inputs ++ selected_coin.selected_inputs)
      |> Enum.sort_by(&extract_ref(&1.output_reference))

    change_output =
      Output.new(cfg.change_address, selected_coin.change, cfg.change_datum)
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
          builder.scripts_lookup,
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

  defp create_tx(
         %TxBody{} = tx_body,
         %TxBuilder{config: %TxConfig{protocol_params: protocol_params}} = builder,
         wallet_utxos,
         %Witness{} = witness_set
       ) do
    with {:ok, %CoinSelection{} = c_selection} <- select_coin(tx_body, wallet_utxos),
         {:ok, %Transaction{} = tx} <- derive_tx(tx_body, c_selection, builder, witness_set),
         {:ok, {final_tx, _rem_utxos}} <- with_collateral(tx, wallet_utxos, builder) do
      # Calculate new Tx Fee
      tx_fee = calc_fee(final_tx, protocol_params)

      if Asset.lovelace_of(tx_body.fee) >= tx_fee do
        {:ok, final_tx}
      else
        %TxBody{
          tx_body
          | inputs: final_tx.tx_body.inputs,
            fee: Asset.from_lovelace(ceil(tx_fee * 1.06))
        }
        |> create_tx(
          builder,
          wallet_utxos -- final_tx.tx_body.inputs,
          tx.witnesses
        )
      end
    end
  end

  defp has_plutus_script?(%{plutus_v1: plutus_v1, plutus_v2: plutus_v2, plutus_v3: plutus_v3}) do
    plutus_v1 != %{} or plutus_v2 != %{} or plutus_v3 != %{}
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
    if has_plutus_script?(builder.scripts_lookup) do
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

  defp select_coin(
         %TxBody{inputs: inputs, outputs: outputs, mint: mint, fee: fee},
         wallet_utxos
       ) do
    total_input_assets =
      Enum.reduce(inputs, %{}, fn i, acc ->
        Asset.merge(i.output.value, acc)
      end)

    positive_mint = Asset.only_positive(mint)
    total_with_mint = Asset.merge(total_input_assets, positive_mint)

    total_output_assets =
      Enum.reduce(outputs, fee, fn o, acc -> Asset.merge(o.value, acc) end)

    diff_asset = Asset.diff(total_with_mint, total_output_assets)

    if Asset.only_positive(diff_asset) == %{} do
      # current inputs is enough to cover output
      {:ok,
       %CoinSelection{
         selected_inputs: [],
         change: Asset.diff(total_output_assets, total_input_assets)
       }}
    else
      # Fetch Utxos for remaining Asset to cover
      diff_inputs = wallet_utxos -- inputs
      LargestFirst.select_utxos(diff_inputs, diff_asset)
    end
  end

  defp alter_outputs_with_min_ada(
         %TxBuilder{config: %TxConfig{protocol_params: protocol_params}} = builder
       ) do
    new_outputs =
      Enum.map(builder.outputs, &calculate_min_ada_for_output(&1, protocol_params))
      |> Enum.reverse()

    %TxBuilder{builder | outputs: new_outputs}
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

  # If transaction includes datums but does not
  # include the redeemers field, the script data format becomes (in hex):
  # [ A0 | datums | A0 ]
  defp calculate_script_data_hash(_cost_models, _script_lookup, datums, nil)
       when not is_nil(datums) do
    ("\xA0" <> CBOR.encode(datums) <> "\xA0")
    |> Blake2b.blake2b_256()
  end

  defp calculate_script_data_hash(%CostModels{} = cost_model, script_lookup, datums, redeemer)
       when is_map(redeemer) and redeemer != %{} do
    lang_views =
      Enum.reduce(script_lookup, %{}, fn {k, v}, acc ->
        cond do
          # Ignore Script that is not used
          v == %{} ->
            acc

          k == :plutus_v1 ->
            # The language ID tag for Plutus V1 is encoded twice. first as a uint then as
            # a bytestring.
            # Concretely, this means that the language version for V1 is encoded as
            # 4100 in hex.
            #
            # The value of cost_models map for v1
            # is encoded as an indefinite length list and the result is encoded as a bytestring.
            # Therefore using %PList{} instead of normal list
            Map.put_new(acc, 0x4100, %PList{value: cost_model.plutus_v1})

          k == :plutus_v2 ->
            Map.put_new(acc, 1, cost_model.plutus_v2)

          k == :plutus_v3 ->
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
