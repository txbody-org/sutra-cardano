defmodule Sutra.Cardano.Transaction.Output do
  @moduledoc """
    Cardano Transaction Output
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Data.Cbor
  alias Sutra.Utils

  import Sutra.Utils, only: [maybe: 3]

  use Sutra.Data

  @type t() :: %__MODULE__{
          address: Address.t(),
          value: Asset.t(),
          datum: Datum.t(),
          reference_script: String.t() | nil
        }

  defdata do
    data(:address, Address)
    data(:value, Asset)
    data(:datum, Datum)
    data(:reference_script, ~OPTION(:string))
  end

  @doc """
    decode CBOR data to Output

    ## CDDL
  """
  def from_cbor([%CBOR.Tag{value: raw_addr} | [assets | dtm_hash]])
      when is_binary(raw_addr) do
    %__MODULE__{
      address: Address.Parser.decode(raw_addr),
      value: Asset.from_cbor(assets),
      datum: dtm_hash |> Utils.safe_head() |> Cbor.extract_value!() |> Datum.from_cbor()
    }
  end

  def from_cbor(%{0 => %CBOR.Tag{tag: :bytes, value: addr_value}} = ops) do
    %__MODULE__{
      address: Address.Parser.decode(addr_value),
      value: Asset.from_cbor(ops[1]),
      datum: Datum.from_cbor(ops[2]),
      reference_script: ops[3]
    }
  end

  @doc """
    encode Output to CBOR data

    ## CDDL
  """
  # Pre babbage Era Output
  def to_cbor(%__MODULE__{datum: %Datum{} = dtm, reference_script: nil} = output)
      when dtm.kind != :inline_datum do
    datum_cbor = if dtm.kind == :datum_hash, do: [Datum.to_cbor(dtm)], else: []

    [
      Address.to_cbor(output.address),
      Asset.to_cbor(output.value)
    ] ++ datum_cbor
  end

  def to_cbor(%__MODULE__{} = output) do
    Enum.reduce(Map.to_list(output) |> tl(), %{}, fn current_val, acc ->
      case current_val do
        {_, nil} ->
          acc

        {:address, addr_info} ->
          Map.put(acc, 0, Address.to_cbor(addr_info))

        {:value, asset_info} ->
          Map.put(acc, 1, Asset.to_cbor(asset_info))

        {:datum, datum_info} ->
          datum_info |> Datum.to_cbor(encoding: :datum_option) |> maybe(acc, &Map.put(acc, 2, &1))

        {:reference_script, script} ->
          Map.put(acc, 3, script)
      end
    end)
  end
end
