defmodule Sutra.Data.MacroHelper.ObjectMacro do
  @moduledoc """
  Macro Helper for Object Macros.

  Generates Blueprint schemas from `defdata` declarations and uses
  `Blueprint.encode/2` and `Blueprint.decode/2` for all encoding/decoding.
  """

  alias __MODULE__, as: ObjectMacro
  alias Sutra.Data.MacroHelper.SchemaBuilder
  alias Sutra.Data.Plutus.Constr

  def __define_object__(opts, block) do
    ast = __setup__object__(block, opts)

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

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp __setup__object__(block, _opts) do
    quote do
      Module.register_attribute(__MODULE__, :__fields, accumulate: true)
      Module.register_attribute(__MODULE__, :__required, accumulate: true)
      Module.register_attribute(__MODULE__, :__field_schemas, accumulate: true)

      alias Sutra.Cardano.Blueprint
      alias Sutra.Data

      unquote(block)
      @enforce_keys @__required
      defstruct @__fields

      # Build the Blueprint schema at compile time
      @__blueprint_schema__ SchemaBuilder.build_object_schema(
                              __MODULE__,
                              Enum.reverse(@__field_schemas)
                            )

      @doc "Returns the Blueprint schema for this type"
      def __schema__, do: @__blueprint_schema__

      @doc "Returns the list of field names in order"
      def __fields__, do: Enum.reverse(@__fields)

      defimpl CBOR.Encoder do
        @impl true
        def encode_into(v, acc),
          do: v.__struct__.to_plutus(v) |> CBOR.Encoder.encode_into(acc)
      end

      @doc "Decode from hex-encoded CBOR or raw Plutus data"
      def from_plutus(data) when is_binary(data) do
        with {:ok, decoded} <- Sutra.Data.decode(data) do
          from_plutus(decoded)
        end
      end

      def from_plutus(%Constr{} = plutus_data) do
        case Blueprint.decode(plutus_data, @__blueprint_schema__) do
          {:ok, %{constructor: _, fields: field_map}} ->
            # Convert string keys to atom keys for struct
            struct_data =
              Enum.reduce(field_map, %{}, fn {key, value}, acc ->
                atom_key = if is_binary(key), do: String.to_atom(key), else: key
                Map.put(acc, atom_key, value)
              end)

            {:ok, struct(__MODULE__, struct_data)}

          error ->
            error
        end
      end

      def from_plutus(nil), do: {:error, %{reason: :cannot_parse_data_nil}}

      @doc "Encode struct to Plutus data"
      def to_plutus(%__MODULE__{} = mod) do
        # Convert struct to format expected by Blueprint.encode
        value = %{
          constructor: ObjectMacro.module_title(__MODULE__),
          fields:
            Enum.reduce(__MODULE__.__fields__(), %{}, fn name, acc ->
              field_value = Map.get(mod, name)
              Map.put(acc, to_string(name), field_value)
            end)
        }

        case Blueprint.encode(value, @__blueprint_schema__) do
          {:ok, encoded} -> encoded
          {:error, reason} -> raise "Encoding failed: #{inspect(reason)}"
        end
      end

      def __plutus_data_info__, do: nil
    end
  end

  @spec __setup_data__(atom(), any(), Keyword.t()) :: Macro.t()
  def __setup_data__(name, type, opts) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      opts = opts || []
      mod = __ENV__.module
      fields = Module.get_attribute(mod, :__fields) || []
      is_virtual = Keyword.get(opts, :virtual, false)

      if Enum.member?(fields, name),
        do: raise(ArgumentError, "The Field #{inspect(name)} already defined")

      Module.put_attribute(mod, :__fields, name)

      # Only add to @__required if not nullable AND not virtual
      if not Sutra.Data.MacroHelper.nullable?(type) and not is_virtual,
        do: Module.put_attribute(mod, :__required, name)

      # Only store field schema for non-virtual fields
      unless is_virtual do
        field_schema = Sutra.Data.MacroHelper.SchemaBuilder.type_to_schema(type)
        Module.put_attribute(mod, :__field_schemas, {name, field_schema})
      end
    end
  end

  # Helper to get module name as title
  def module_title(module) do
    module
    |> Module.split()
    |> List.last()
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
end
