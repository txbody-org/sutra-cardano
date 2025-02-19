defmodule Sutra.Common do
  @moduledoc """
    Common used types
  """

  use TypedStruct

  typedstruct(module: RationalNumber) do
    field(:numerator, :integer, required: true)
    field(:denominator, :integer, required: true)
  end

  typedstruct(module: ExecutionUnitPrice) do
    field(:mem_price, RationalNumber)
    field(:step_price, RationalNumber)
  end

  typedstruct(module: ExecutionUnits) do
    field(:mem, pos_integer())
    field(:step, pos_integer())
  end
end
