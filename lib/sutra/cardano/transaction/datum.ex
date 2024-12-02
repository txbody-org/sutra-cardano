defmodule Sutra.Cardano.Transaction.Datum do
  @moduledoc """
    Cardano Transaction Datum
  """
  alias Sutra.Data.Cbor

  import Sutra.Data.Cbor, only: [extract_value!: 1]

  use Sutra.Data

  defenum(no_datum: :null, datum_hash: :string, inline_datum: :string)

  def from_cbor(cbor) do
    case cbor do
      datum_hash when is_binary(datum_hash) ->
        %__MODULE__{kind: :datum_hash, value: datum_hash}

      [0, datum_hash] ->
        %__MODULE__{kind: :datum_hash, value: datum_hash}

      [1, %CBOR.Tag{tag: 24, value: data_value}] ->
        %__MODULE__{kind: :inline_datum, value: extract_value!(data_value)}

      _ ->
        %__MODULE__{kind: :no_datum}
    end
  end

  def to_cbor(%__MODULE__{} = datum, opts \\ []) do
    case datum do
      %__MODULE__{kind: :datum_hash, value: datum_hash} ->
        if Keyword.get(opts, :encoding) == :datum_option,
          do: [0, Cbor.as_byte(datum_hash)],
          else: Cbor.as_byte(datum_hash)

      %__MODULE__{kind: :inline_datum, value: data} ->
        [1, %CBOR.Tag{tag: 24, value: Cbor.as_byte(data)}]

      _ ->
        nil
    end
  end
end
