defmodule Sutra.Data.Cbor do
  @moduledoc """

    CBOR handling
  """

  def extract_value(%CBOR.Tag{value: value}), do: value
  def extract_value(%Sutra.Data.Plutus.PList{value: value}), do: value
  def extract_value(value), do: value
end
