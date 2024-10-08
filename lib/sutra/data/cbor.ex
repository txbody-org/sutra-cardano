defmodule Sutra.Data.Cbor do
  @moduledoc """

    CBOR handling
  """

  def extract_value(%CBOR.Tag{value: value}), do: {:ok, value}
  def extract_value(%Sutra.Data.Plutus.PList{value: value}), do: {:ok, value}
  def extract_value(value), do: {:ok, value}
end
