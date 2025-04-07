defmodule Sutra.Data.MacroHelper.EnumMacro do
  @moduledoc """
    Helper function to define Enum
  """

  alias Sutra.Data.Cbor
  alias Sutra.Data.Plutus.Constr
  alias __MODULE__, as: EnumMacro
  alias Sutra.Data.MacroHelper

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
            type = Keyword.get(kind_info, :field_kind)

            exact_index = Keyword.get(kind_info, :index, indx)

            with_encoded_decoded_info =
              MacroHelper.with_encoder_decoder(type, kind_info)
              |> Keyword.put(:index, exact_index)

            def unquote(:__enum_kind__)(unquote(exact_index)) do
              unquote(kind)
            end

            def unquote(:__enum_field__)(unquote(kind)),
              do: unquote(Macro.escape(with_encoded_decoded_info))
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

        case {MacroHelper.handle_from_plutus(field_info, kind, flds), field_info[:field_kind]} do
          {{:ok, _}, :null} ->
            {:ok, %__MODULE__{kind: kind, value: nil}}

          {{:ok, [value]}, _} ->
            {:ok, %__MODULE__{kind: kind, value: Cbor.extract_value!(value)}}

          {{:ok, value}, _} ->
            {:ok, %__MODULE__{kind: kind, value: value}}

          {error, _} ->
            error
        end
      end

      def to_plutus(%__MODULE__{} = mod) do
        field_info = apply(__MODULE__, :__enum_field__, [mod.kind])

        encode_fn =
          if is_function(field_info[:encode_with], 1),
            do: field_info[:encode_with],
            else: fn v ->
              MacroHelper.handle_to_plutus(field_info, v)
            end

        value = if is_nil(mod.value), do: [], else: encode_fn.(mod.value)

        %Constr{
          index: field_info[:index],
          fields: if(is_list(value), do: value, else: [value])
        }
      end
    end
  end

  def prepare_kind_info(kind_info) when kind_info == :null or kind_info == nil,
    do: [field_kind: :null]

  def prepare_kind_info(kind_info) when is_atom(kind_info),
    do: [field_kind: kind_info]

  def prepare_kind_info(kind_info) when is_list(kind_info),
    do: kind_info

  def prepare_kind_info(kind_info) when is_tuple(kind_info), do: [field_kind: kind_info]

  def prepare_kind_info(kind_info),
    do: raise(ArgumentError, "Invalid Argument #{inspect(kind_info)}")
end
