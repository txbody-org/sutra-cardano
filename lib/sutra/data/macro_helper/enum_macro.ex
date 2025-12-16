defmodule Sutra.Data.MacroHelper.EnumMacro do
  @moduledoc """
  Macro Helper for Enum definitions.

  Generates Blueprint schemas from `defenum` declarations and uses
  `Blueprint.encode/2` and `Blueprint.decode/2` for all encoding/decoding.

  ## Usage

  Define enum with explicit field names and types:

      defenum name: Datum do
        field :no_datum, :null
        field :datum_hash, :string
        field :inline_datum, :string
      end

  With explicit constructor indices:

      defenum name: Datum do
        field :inline_datum, :string, index: 1
        field :datum_hash, :string, index: 0
        field :no_datum, :null, index: 2
      end

  With tuple fields (multiple constructor arguments):

      defenum name: UserRole do
        field :admin, {:string, :integer}
        field :normal, {:string, :string, :string}
      end
  """

  alias Sutra.Cardano.Blueprint
  alias Sutra.Data.MacroHelper.SchemaBuilder
  alias Sutra.Data.Plutus.Constr
  alias __MODULE__, as: EnumMacro

  @doc "Define an enum with a block of field declarations"
  def __define__(opts, block) do
    ast = prepare_ast_with_block(opts, block)

    case opts[:name] do
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

  @doc "Define an enum without explicit name (inline or do block)"
  def __define__(opts) when is_list(opts) do
    cond do
      # Handle defenum do ... end (opts is [do: block])
      block = opts[:do] ->
        opts = Keyword.delete(opts, :do)
        __define__(opts, block)

      Keyword.has_key?(opts, :name) or Keyword.has_key?(opts, :module) ->
        raise ArgumentError, "defenum with :name / :module requires a do block"

      true ->
        raise ArgumentError,
              "Legacy defenum syntax is no longer supported. Use block syntax: defenum do field :name, :type end"
    end
  end

  # ============================================================================
  # New Block-Based Implementation
  # ============================================================================

  defp prepare_ast_with_block(_opts, block) do
    preamble = preamble_ast(block)
    helpers = helpers_ast()
    postamble = postamble_ast()

    quote do
      unquote(preamble)
      unquote(helpers)
      unquote(postamble)
    end
  end

  defp preamble_ast(block) do
    quote do
      Module.register_attribute(__MODULE__, :__enum_fields, accumulate: true)

      import Sutra.Data.MacroHelper.EnumMacro, only: [field: 2, field: 3]

      unquote(block)

      @type t() :: %__MODULE__{kind: atom(), value: any()}
      @enforce_keys [:kind]
      defstruct [:kind, :value]

      alias Sutra.Cardano.Blueprint
    end
  end

  defp helpers_ast do
    quote do
      # Build variants from accumulated fields
      @__variants__ EnumMacro.build_variants(@__enum_fields)

      # Build the Blueprint schema at compile time
      @__blueprint_schema__ SchemaBuilder.build_enum_schema(__MODULE__, @__variants__)

      @doc "Returns the Blueprint schema for this enum"
      def __schema__, do: @__blueprint_schema__

      # Generate kind/index lookup functions
      for {kind, index, _} <- @__variants__ do
        @__current_kind__ kind
        @__current_index__ index

        def __enum_kind__(@__current_index__), do: @__current_kind__
        def __enum_index__(@__current_kind__), do: @__current_index__
      end
    end
  end

  defp postamble_ast do
    quote do
      defimpl CBOR.Encoder do
        @impl true
        def encode_into(v, acc),
          do: v.__struct__.to_plutus(v) |> CBOR.Encoder.encode_into(acc)
      end

      @doc "Decode from hex-encoded CBOR or raw Plutus data"
      def from_plutus(data) when is_binary(data) do
        case Sutra.Data.decode(data) do
          {:ok, decoded} -> from_plutus(decoded)
          {:error, reason} -> {:error, reason}
        end
      end

      def from_plutus(%Constr{index: index} = plutus_data) do
        EnumMacro.handle_decoded_enum(
          Blueprint.decode(plutus_data, @__blueprint_schema__),
          index,
          __MODULE__
        )
      end

      def from_plutus(nil), do: {:error, %{reason: :invalid_enum_data_to_parse_from_nil}}

      @doc "Encode enum to Plutus data"
      def to_plutus(%__MODULE__{kind: kind, value: value}) do
        EnumMacro.encode_enum_value(kind, value, @__variants__, @__blueprint_schema__)
      end
    end
  end

  @doc false
  defmacro field(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      index = Keyword.get(opts, :index)
      Module.put_attribute(__MODULE__, :__enum_fields, {name, type, index})
    end
  end

  @doc "Build variant list from accumulated fields"
  def build_variants(fields) do
    fields
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {{name, type, explicit_index}, auto_index} ->
      index = explicit_index || auto_index
      field_schema = SchemaBuilder.type_to_schema(type)
      {name, index, field_schema}
    end)
    |> Enum.sort_by(fn {_, index, _} -> index end)
  end

  @doc "Extract value from decoded field map"
  def extract_enum_value(field_map) when map_size(field_map) == 0, do: nil

  def extract_enum_value(field_map) when map_size(field_map) == 1 do
    [{_key, value}] = Map.to_list(field_map)
    value
  end

  def extract_enum_value(field_map) do
    # Multiple fields - return as tuple in order
    field_map
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {_, v} -> v end)
    |> List.to_tuple()
  end

  @doc "Build the encode value structure for Blueprint"
  def build_enum_encode_value(nil, nil, variant_title) do
    %{constructor: variant_title, fields: %{}}
  end

  def build_enum_encode_value(nil, _schema, variant_title) do
    %{constructor: variant_title, fields: %{}}
  end

  def build_enum_encode_value(value, schema, variant_title) when is_tuple(value) do
    # Tuple fields - check if schema expects positional fields
    case schema do
      %{"dataType" => "list", "items" => items} when is_list(items) ->
        # It's a tuple type schema - convert to named positional fields
        fields =
          value
          |> Tuple.to_list()
          |> Enum.with_index()
          |> Enum.into(%{}, fn {v, idx} -> {"field_#{idx}", v} end)

        %{constructor: variant_title, fields: fields}

      _ ->
        %{constructor: variant_title, fields: %{"value" => value}}
    end
  end

  def build_enum_encode_value(value, _schema, variant_title) do
    %{constructor: variant_title, fields: %{"value" => value}}
  end

  # Helper to encode nested structs
  def maybe_encode_nested(value) when is_struct(value) do
    if function_exported?(value.__struct__, :to_plutus, 1) do
      value.__struct__.to_plutus(value)
    else
      value
    end
  end

  def maybe_encode_nested(value) when is_list(value) do
    Enum.map(value, &maybe_encode_nested/1)
  end

  def maybe_encode_nested(value), do: value

  @doc "Handle the result of Blueprint.decode for enum generation"
  def handle_decoded_enum({:ok, nil}, index, module) do
    # None variant (null type)
    kind = module.__enum_kind__(index)
    {:ok, struct(module, kind: kind, value: nil)}
  end

  def handle_decoded_enum(
        {:ok, %{constructor: constructor_name, fields: field_map}},
        _index,
        module
      )
      when map_size(field_map) == 0 do
    kind = constructor_name |> Macro.underscore() |> String.to_atom()
    {:ok, struct(module, kind: kind, value: nil)}
  end

  def handle_decoded_enum(
        {:ok, %{constructor: constructor_name, fields: field_map}},
        _index,
        module
      ) do
    kind = constructor_name |> Macro.underscore() |> String.to_atom()
    value = EnumMacro.extract_enum_value(field_map)
    {:ok, struct(module, kind: kind, value: value)}
  end

  def handle_decoded_enum({:ok, value}, index, module) do
    # Direct value (e.g., from tuple field)
    kind = module.__enum_kind__(index)
    {:ok, struct(module, kind: kind, value: value)}
  end

  def handle_decoded_enum(error, _index, _module), do: error

  @doc "Encode an enum value to Plutus data"
  def encode_enum_value(kind, value, variants, schema) do
    variant_title = kind |> to_string() |> Macro.camelize()

    {_, _index, field_schema} =
      Enum.find(variants, fn {k, _, _} -> k == kind end)

    encoded_value = build_enum_encode_value(value, field_schema, variant_title)

    case Blueprint.encode(encoded_value, schema) do
      {:ok, encoded} -> encoded
      {:error, reason} -> raise "Encoding failed: #{inspect(reason)}"
    end
  end
end
