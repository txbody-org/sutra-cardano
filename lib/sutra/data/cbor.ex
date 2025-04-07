defmodule Sutra.Data.Cbor do
  @moduledoc """

    CBOR handling
  """
  alias Sutra.Data.Plutus.PList

  @type t() :: %PList{} | %CBOR.Tag{} | map()

  alias Sutra.Utils

  def extract_value(%CBOR.Tag{tag: :bytes, value: value}),
    do: {:ok, Base.encode16(value)}

  def extract_value(%CBOR.Tag{value: value}), do: {:ok, value}
  def extract_value(%Sutra.Data.Plutus.PList{value: value}), do: {:ok, value}
  def extract_value(value), do: {:ok, value}

  def extract_value!(v) do
    extract_value(v)
    |> Utils.ok_or(fn -> raise "Invalid CBOR value: #{inspect(v)}" end)
  end

  def as_byte(value) when is_binary(value) do
    %CBOR.Tag{tag: :bytes, value: Utils.ok_or(Base.decode16(value, case: :mixed), value)}
  end

  def as_nonempty_set(value), do: %CBOR.Tag{tag: 258, value: value}
  def as_set(value), do: %CBOR.Tag{tag: 258, value: value}

  def as_indexed_map(value, index, map \\ %{}) do
    Map.put(map, index, value)
  end

  def as_unit_interval({numerator, denomanator}) do
    %CBOR.Tag{tag: 30, value: [numerator, denomanator]}
  end

  def as_tagged(values) when is_list(values) do
    %PList{value: Enum.map(values, &as_tagged/1)}
  end

  def as_tagged(value) when is_binary(value), do: as_byte(value)

  def as_tagged(value), do: value

  def encode_hex(data), do: CBOR.encode(data) |> Base.encode16()
end
