defmodule Sutra.Uplc do
  @moduledoc """
    Handle UPLC
  """
  alias Sutra.Cardano.Gov
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.{Input, Output, OutputReference, TxBody, Witness}
  alias Sutra.Data

  use Rustler, otp_app: :sutra_cardano, crate: "sutra_uplc"

  def evaluate_raw(tx_cbor, inputs, %CostModels{} = cost_models, slot_config)
      when is_binary(tx_cbor) do
    utxos =
      Input.sort_inputs(inputs)
      |> Enum.map(fn input = %Input{} ->
        {OutputReference.to_cbor(input.output_reference) |> CBOR.encode(),
         Output.to_cbor(input.output) |> CBOR.encode()}
      end)

    cost_models_bytes = Gov.encode_cost_models(cost_models)

    case eval_phase_two(
           tx_cbor,
           utxos,
           cost_models_bytes,
           # TODO: use from params
           {10_000_000_000, 14_000_000},
           slot_config
         ) do
      {true, result} ->
        # TODO: print logs
        redeemers =
          Enum.map(result, fn %{redeemer_info: r, logs: _logs} ->
            {:ok, decoded, _} = :erlang.list_to_binary(r) |> CBOR.decode()
            Witness.decode({5, decoded})
          end)

        {:ok, redeemers}

      {false, error} ->
        {:error, error}
    end
  end

  def evaluate(
        %Transaction{tx_body: %TxBody{inputs: inputs, reference_inputs: ref_inputs}} = tx,
        cost_models,
        slot_config
      ) do
    ref_inputs = ref_inputs || []

    tx
    |> Transaction.to_cbor()
    |> CBOR.encode()
    |> evaluate_raw(inputs ++ ref_inputs, cost_models, slot_config)
  end

  # NIF function stub - actual implementation in Rust
  def eval_phase_two(_tx_bytes, _utxos, _cost_models, _initial_budget, _slot_config),
    do: :erlang.nif_error(:nif_not_loaded)

  def do_apply_params_to_script(_script, _params), do: :erlang.nif_error(:nif_not_loaded)

  def apply_params_to_script(script, params) when is_binary(script) do
    # script_raw = Base.decode16!(script, case: :mixed)
    encoded_params = Data.encode(params)

    case do_apply_params_to_script(script, encoded_params) do
      {true, applied_script} ->
        :erlang.list_to_binary(applied_script) |> Base.encode16()

      {false, error} ->
        raise """
           Apply params error

          #{error}
        """
    end
  end
end
