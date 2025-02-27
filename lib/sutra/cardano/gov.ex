defmodule Sutra.Cardano.Gov do
  @moduledoc """
    Governance related actions
  """

  use TypedStruct

  typedstruct(module: CostModels) do
    field(:plutus_v1, [])
    field(:plutus_v2, [])
    field(:plutus_v3, [])
  end

  def encode_cost_models(%__MODULE__.CostModels{} = cost_models) do
    CBOR.encode(%{
      0 => cost_models.plutus_v1,
      1 => cost_models.plutus_v2,
      2 => cost_models.plutus_v3
    })
  end
end
