defmodule Sutra.Common do
  @moduledoc """
    Common used types
  """

  @type ratio() :: {integer(), pos_integer()}
  @type ex_price() :: ratio()

  use TypedStruct

  typedstruct(module: RationalNumber) do
    field(:numerator, :integer, required: true)
    field(:denominator, :integer, required: true)
  end

  typedstruct(module: ExecutionUnitPrice) do
    field(:mem_price, Sutra.Common.ex_price())
    field(:step_price, Sutra.Common.ex_price())
  end

  typedstruct(module: ExecutionUnits) do
    field(:mem, pos_integer())
    field(:step, pos_integer())
  end

  def rational_from_binary(str) when is_binary(str) do
    case String.split(str, "/") do
      [n, d] ->
        %RationalNumber{numerator: String.to_integer(n), denominator: String.to_integer(d)}

      _ ->
        nil
    end
  end
end
