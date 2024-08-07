defmodule Sutra.Cardano.Data do
  @moduledoc """
    Plutus Data
  """

  use TypedStruct

  alias __MODULE__, as: Data
  alias __MODULE__.Constr, as: Constr
  alias __MODULE__.PList, as: PList

  @type pbytes() :: String.t()
  @type pInt() :: pos_integer()
  @type pMap() :: [{Data.t(), Data.t()}]

  @type t() :: Constr.t() | pMap() | PList.t() | pInt() | pbytes()

  typedstruct module: Constr do
    @moduledoc """
      Data Constr
    """
    field(:index, Integer.t(), enforce: true)
    field(:fields, [Data.t()], enforce: true)
  end

  defmodule PList do
    typedstruct do
      @moduledoc """
        Phantom type for Plutus List as List is encoded  weirdly.

        For empty list, it is encoded as definite empty lists (0x80)
        For non-empty list, it is encoded as indefinite lists
      """
      field(:value, [Data.t()], enforce: true)
    end

    alias __MODULE__, as: PList

    defimpl CBOR.Encoder do
      @impl true
      def encode_into(%PList{value: []}, acc), do: <<acc::binary, 0x80>>

      def encode_into(%PList{value: list}, acc) do
        Enum.reduce(list, <<acc::binary, 0x9F>>, fn v, acc ->
          CBOR.Encoder.encode_into(v, acc)
        end) <> <<0xFF>>
      end
    end
  end

  @spec decode(binary()) :: {:ok, CBOR.Tag.t()} | {:error, any()}
  def decode(cbor) do
    with {:ok, bytes} <- Base.decode16(cbor, case: :mixed),
         {:ok, cbor_decoded, _} <- CBOR.decode(bytes) do
      {:ok, decode_cbor_tag(cbor_decoded)}
    end
  end

  defp decode_cbor_tag(%CBOR.Tag{tag: :bytes} = tag), do: tag

  defp decode_cbor_tag(%CBOR.Tag{tag: n} = tag) when is_integer(n) and n >= 121 and n < 128,
    do: %Constr{index: n - 121, fields: Enum.map(tag.value, &decode_cbor_tag/1)}

  defp decode_cbor_tag(%CBOR.Tag{tag: n} = tag) when is_integer(n) and n >= 1280 and n < 1401,
    do: %Constr{index: n - 1280 + 7, fields: Enum.map(tag.value, &decode_cbor_tag/1)}

  defp decode_cbor_tag(%CBOR.Tag{tag: 102} = _tag),
    do: raise("TODO: Handle alternatives 102")

  defp decode_cbor_tag(%CBOR.Tag{tag: n} = _tag) when is_integer(n),
    do: raise("Invalid Tag: #{n}")

  defp decode_cbor_tag(tags) when is_list(tags),
    do: %PList{value: Enum.map(tags, &decode_cbor_tag/1)}

  defp decode_cbor_tag(%CBOR.Tag{tag: tag}), do: raise("Not Implemented: tag: #{tag}")
  defp decode_cbor_tag(tag), do: tag

  def encode(data) do
    data
    |> encode_data()
    |> CBOR.encode()
    |> Base.encode16(case: :lower)
  end

  defp encode_data(%Constr{index: index, fields: fields}) when index >= 0 and index < 7 do
    %CBOR.Tag{tag: index + 121, value: %PList{value: Enum.map(fields, &encode_data/1)}}
  end

  defp encode_data(%Constr{index: index, fields: fields}) when index >= 7 and index < 128 do
    %CBOR.Tag{tag: 1280 + (index - 7), value: %PList{value: Enum.map(fields, &encode_data/1)}}
  end

  defp encode_data(%PList{} = list) do
    list
  end

  defp encode_data(d) when is_list(d) do
    Enum.map(d, &encode_data/1)
  end

  defp encode_data(d) when is_binary(d) do
    %CBOR.Tag{tag: :bytes, value: d}
  end

  defp encode_data(d), do: d
end
