defmodule Sutra.Cardano.Asset do
  @moduledoc """
    Cardano Asset
  """

  alias Sutra.Data

  import Sutra.Data.Cbor, only: [extract_value: 1]

  def from_plutus(cbor) when is_binary(cbor) do
    case Data.decode(cbor) do
      {:ok, data} -> from_plutus(data)
      {:error, _} -> {:error, :invalid_cbor}
    end
  end

  def from_plutus(plutus_data) when is_map(plutus_data) do
    result =
      Enum.reduce(plutus_data, %{}, fn {key, val}, acc ->
        key =
          case extract_value(key) do
            {:ok, ""} -> "lovelace"
            {:ok, value} -> value
          end

        Map.put(acc, key, to_asset_class(val))
      end)

    {:ok, result}
  end

  defp to_asset_class(%{%CBOR.Tag{tag: :bytes, value: ""} => lovelace}),
    do: lovelace

  defp to_asset_class(value) when is_map(value) do
    Enum.reduce(value, %{}, fn {key, val}, acc ->
      {:ok, key} = extract_value(key)
      Map.put(acc, key, val)
    end)
  end

  def to_plutus(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, val}, acc ->
      key_val =
        case key do
          "lovelace" -> ""
          _ -> key
        end

      acc
      |> Map.put(%CBOR.Tag{tag: :bytes, value: key_val}, from_asset_class(val))
    end)
  end

  def to_plutus(_val), do: {:error, :invalid_data}

  defp from_asset_class(lovelace_value) when is_integer(lovelace_value),
    do: %{%CBOR.Tag{tag: :bytes, value: ""} => lovelace_value}

  defp from_asset_class(asset_map) when is_map(asset_map) do
    Enum.reduce(asset_map, %{}, fn {key, val}, acc ->
      key = %CBOR.Tag{tag: :bytes, value: key}
      Map.put(acc, key, val)
    end)
  end
end