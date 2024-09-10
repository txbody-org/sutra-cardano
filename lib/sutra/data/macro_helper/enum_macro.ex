defmodule Sutra.Data.MacroHelper.EnumMacro do
  @moduledoc """
    Helper function to define Enum
  """

  alias Sutra.Data.Plutus.Constr
  alias __MODULE__, as: EnumMacro
  alias Sutra.Data.MacroHelper
  alias Sutra.Utils

  import Sutra.Data.Cbor, only: [extract_value: 1]

  def __define__(opts) do
    ast = prepare_ast(Keyword.delete(opts, :module))

    case opts[:module] do
      nil ->
        quote do
          unquote(ast)
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def prepare_ast(fields) do
    quote bind_quoted: [fields: fields] do
      @type t() :: %__MODULE__{kind: atom(), value: any()}

      ## Need to validate the fields
      @enforce_keys [:kind]
      defstruct [:kind, :value]

      quote do
        unquote(
          Enum.with_index(fields, fn {kind, kind_info}, indx ->
            kind_info = EnumMacro.prepare_kind_info(kind_info)
            type = Keyword.get(kind_info, :type)

            with_encoded_decoded_info = MacroHelper.with_encoder_decoder(type, kind_info)

            exact_index = Keyword.get(kind_info, :index, indx)

            def unquote(:__enum_kind__)(unquote(exact_index)) do
              unquote(kind)
            end

            def unquote(:__enum_field__)(unquote(kind)),
              do: unquote(Keyword.put(with_encoded_decoded_info, :index, exact_index))
          end)
        )
      end

      def from_plutus(data) when is_binary(data) do
        case Sutra.Data.decode(data) do
          {:ok, decoded} -> from_plutus(decoded)
          {:error, reason} -> {:error, reason}
        end
      end

      def from_plutus(%Constr{index: indx, fields: flds}) do
        kind = apply(__MODULE__, :__enum_kind__, [indx])
        field_info = apply(__MODULE__, :__enum_field__, [kind])

        decode_fn =
          if is_function(field_info[:decode_with], 1),
            do: field_info[:decode_with],
            else: &extract_value/1

        with {:ok, value} <- decode_fn.(Utils.safe_head(flds)) do
          {:ok, %__MODULE__{kind: kind, value: value}}
        end
      end

      def to_plutus(%__MODULE__{} = mod) do
        field_info = apply(__MODULE__, :__enum_field__, [mod.kind])

        encode_fn =
          if is_function(field_info[:encode_with], 1),
            do: field_info[:encode_with],
            else: &Sutra.Utils.identity/1

        value = if is_nil(mod.value), do: [], else: [encode_fn.(mod.value)]

        %Constr{
          index: field_info[:index],
          fields: value
        }
      end
    end
  end

  def prepare_kind_info(kind_info) when kind_info == :null or kind_info == nil,
    do: [type: :null]

  def prepare_kind_info(kind_info) when is_atom(kind_info),
    do: [type: kind_info]

  def prepare_kind_info(kind_info) when is_list(kind_info),
    do: kind_info

  def prepare_kind_info(kind_info),
    do: raise(ArgumentError, "Invalid Argument #{inspect(kind_info)}")
end
