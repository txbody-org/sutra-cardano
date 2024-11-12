defmodule Sutra.Data.Cbor do
  @moduledoc """

    CBOR handling
  """
  def extract_value(%CBOR.Tag{tag: :bytes, value: value}), do: {:ok, Base.encode16(value)}
  def extract_value(%CBOR.Tag{value: value}), do: {:ok, value}
  def extract_value(%Sutra.Data.Plutus.PList{value: value}), do: {:ok, value}
  def extract_value(value), do: {:ok, value}

  def extract_value!(v) do
    case extract_value(v) do
      {:ok, value} -> value
      {:error, _} -> raise "Invalid CBOR value: #{inspect(v)}"
    end
  end
end
