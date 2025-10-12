defmodule Sutra.Data.Plutus do
  @moduledoc """
    Plutus data
  """

  use TypedStruct

  alias Sutra.Data.Cbor
  alias __MODULE__, as: Plutus
  alias __MODULE__.PList

  @type pbytes() :: String.t()
  @type pInt() :: pos_integer()
  @type pMap() :: [{__MODULE__.t(), __MODULE__.t()}]

  @type t() :: %__MODULE__.Constr{} | pMap() | __MODULE__.PList.t() | pInt() | pbytes()

  defmodule PList do
    @moduledoc """
      Phantom type for Plutus List as List is encoded  weirdly.

      For empty list, it is encoded as definite empty lists (0x80)
      For non-empty list, it is encoded as indefinite lists
    """

    defstruct [:value]

    @type t() :: %__MODULE__{value: [Plutus.t()]}

    defimpl CBOR.Encoder do
      @impl true
      def encode_into(%PList{value: []}, acc), do: <<acc::binary, 0x80>>

      def encode_into(%PList{value: %PList{} = val}, acc) do
        CBOR.Encoder.encode_into(val, acc)
      end

      def encode_into(%PList{value: list}, acc) do
        Enum.reduce(list, <<acc::binary, 0x9F>>, fn v, acc ->
          CBOR.Encoder.encode_into(v, acc)
        end) <> <<0xFF>>
      end
    end
  end

  defmodule Constr do
    @moduledoc """
      Data Constr
    """

    typedstruct do
      field(:index, pos_integer(), enforce: true)
      field(:fields, [Plutus.t()], enforce: true)
    end

    defimpl CBOR.Encoder do
      @impl true
      def encode_into(%Constr{index: index, fields: fields}, acc) when is_integer(index) do
        tag =
          if index >= 0 and index < 7,
            do: index + 121,
            else: 1280 + (index - 7)

        constr = %CBOR.Tag{
          tag: tag,
          value: %PList{
            value: Cbor.as_tagged(fields)
          }
        }

        CBOR.Encoder.encode_into(constr, acc)
      end
    end
  end

  defguard is_plutus_data(data)
           when is_struct(data, __MODULE__.Constr) or is_struct(data, __MODULE__.PList) or
                  is_binary(data) or is_integer(data)

  @spec decode(binary() | Cbor.t() | integer()) :: {:ok, __MODULE__.t()} | {:error, any()}
  def decode(raw) when is_binary(raw) do
    with {:ok, bytes} <- normalize_bytes(raw),
         {:ok, cbor_decoded, _} <- CBOR.decode(bytes) do
      {:ok, decode_cbor_tag(cbor_decoded)}
    end
  end

  def decode(data), do: {:ok, decode_cbor_tag(data)}

  defp normalize_bytes(str) when is_binary(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      _ -> {:ok, str}
    end
  end

  def decode!(cbor) do
    case decode(cbor) do
      {:ok, decoded} -> decoded
      {:error, reason} -> raise reason
    end
  end

  defp decode_cbor_tag(%CBOR.Tag{tag: :bytes} = tag), do: tag

  defp decode_cbor_tag(%CBOR.Tag{tag: n} = tag) when is_integer(n) and n >= 121 and n < 128,
    do: %Constr{index: n - 121, fields: Enum.map(tag.value, &decode_cbor_tag/1)}

  defp decode_cbor_tag(%CBOR.Tag{tag: n} = tag) when is_integer(n) and n >= 1280 and n < 1401,
    do: %Constr{index: n - 1280 + 7, fields: Enum.map(tag.value, &decode_cbor_tag/1)}

  defp decode_cbor_tag(%CBOR.Tag{tag: 102} = _tag),
    do: raise("TODO: Handle alternatives 102")

  defp decode_cbor_tag(%CBOR.Tag{tag: n} = tag) when is_integer(n),
    do: tag

  defp decode_cbor_tag(tags) when is_list(tags),
    do: Enum.map(tags, &decode_cbor_tag/1)

  defp decode_cbor_tag(%CBOR.Tag{tag: tag}), do: raise("Not Implemented: tag: #{tag}")
  defp decode_cbor_tag(tag), do: tag

  def encode(struct) when is_struct(struct) do
    if function_exported?(struct.__struct__, :to_plutus, 1),
      do: struct.__struct__.to_plutus(struct) |> do_encode(),
      else: do_encode(struct)
  end

  def encode(data), do: do_encode(data)

  defp do_encode(data) do
    data
    |> Cbor.as_tagged()
    |> CBOR.encode()
  end
end
