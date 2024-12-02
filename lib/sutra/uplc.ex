defmodule Sutra.Uplc do
  @moduledoc """
    Handle UPLC
  """

  use Rustler, otp_app: :sutra_offchain, crate: "sutra_uplc"

  # NIF function stub - actual implementation in Rust
  def eval_phase_two(_tx_bytes, _utxos, _cost_models, _initial_budget, _slot_config),
    do: :erlang.nif_error(:nif_not_loaded)
end
