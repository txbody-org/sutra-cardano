defmodule Sutra.Cardano.Blueprint do
  @moduledoc """
  Blueprint parser for encoding and decoding Plutus data based on CIP-57 blueprint schemas.

  This module provides functionality to:
  - Encode Elixir values into Plutus data based on schema definitions
  - Decode Plutus data into Elixir values based on schema definitions

  ## Schema Types Supported

  - **bytes**: Binary data (hex-encoded strings or raw binaries)
  - **integer**: Integers
  - **list**: Lists with homogeneous items
  - **constructor**: Tagged constructors (enums/records)
  - **map**: Key-value pairs
  - **$ref**: References to other definitions

  ## Example

      # Load a blueprint
      {:ok, blueprint_json} = File.read("plutus.json")
      {:ok, blueprint} = Jason.decode(blueprint_json)

      # Get a schema definition
      schema = %{"$ref" => "#/definitions/nuvola/types/LendingRedeemer"}

      # Encode a value
      value = %{constructor: "CreateLend", fields: %{}}
      {:ok, plutus_data} = Blueprint.encode(value, schema, blueprint["definitions"])

      # Decode plutus data back
      {:ok, decoded} = Blueprint.decode(plutus_data, schema, blueprint["definitions"])
  """

  alias Sutra.Data.Plutus
  alias Sutra.Data.Plutus.{Constr, PList}

  @type schema :: map()
  @type definitions :: map()
  @type encode_error :: {:error, {:encode_error, String.t()}}
  @type decode_error :: {:error, {:decode_error, String.t()}}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Encodes an Elixir value into Plutus data based on the provided schema.

  ## Parameters

  - `value` - The Elixir value to encode
  - `schema` - The schema definition (map with schema type info or $ref)
  - `definitions` - Optional map of all definitions from the blueprint (required for $ref)

  ## Returns

  - `{:ok, plutus_data}` - Successfully encoded Plutus data
  - `{:error, reason}` - Encoding failed

  ## Examples

      # Encode an integer
      iex> Blueprint.encode(42, %{"dataType" => "integer"})
      {:ok, 42}

      # Encode bytes
      iex> Blueprint.encode("deadbeef", %{"dataType" => "bytes"})
      {:ok, <<222, 173, 190, 239>>}

      # Encode a constructor
      iex> schema = %{
      ...>   "anyOf" => [
      ...>     %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => []}
      ...>   ]
      ...> }
      iex> Blueprint.encode(%{constructor: "Foo"}, schema)
      {:ok, %Constr{index: 0, fields: []}}
  """
  @spec encode(any(), schema(), definitions()) :: {:ok, Plutus.t()} | encode_error()
  def encode(value, schema, definitions \\ %{})

  def encode(value, %{"$ref" => ref}, definitions) do
    case resolve_ref(ref, definitions) do
      {:ok, resolved_schema} -> encode(value, resolved_schema, definitions)
      error -> error
    end
  end

  # Handle "anyOf" schemas (constructors/enums)
  def encode(value, %{"anyOf" => variants}, definitions) do
    encode_constructor(value, variants, definitions)
  end

  # Handle primitive types
  def encode(value, %{"dataType" => "bytes"}, _definitions) do
    encode_bytes(value)
  end

  def encode(value, %{"dataType" => "integer"}, _definitions) do
    encode_integer(value)
  end

  # Handle lists with single item schema (homogeneous list)
  def encode(value, %{"dataType" => "list", "items" => items}, definitions) when is_map(items) do
    encode_list(value, items, definitions)
  end

  # Handle tuples (list with array of item schemas)
  def encode(value, %{"dataType" => "list", "items" => items}, definitions)
      when is_list(items) do
    encode_tuple(value, items, definitions)
  end

  # Handle map type
  def encode(
        value,
        %{"dataType" => "map", "keys" => keys_schema, "values" => values_schema},
        definitions
      ) do
    encode_map(value, keys_schema, values_schema, definitions)
  end

  # Handle single constructor schema (not wrapped in anyOf)
  def encode(value, %{"dataType" => "constructor"} = schema, definitions) do
    # Wrap in anyOf and delegate to constructor encoding
    encode_constructor(value, [schema], definitions)
  end

  # Handle "Data" type (any plutus data - pass through)
  def encode(value, %{"title" => "Data"}, _definitions) do
    {:ok, value}
  end

  # Handle module reference - delegate to module's schema/functions
  def encode(value, %{"$module" => module}, _definitions) when is_atom(module) do
    Code.ensure_loaded(module)

    cond do
      # If value is already the right struct and module has to_plutus, use it
      is_struct(value) and function_exported?(value.__struct__, :to_plutus, 1) ->
        {:ok, value.__struct__.to_plutus(value)}

      # If module has __schema__, use Blueprint with that schema
      function_exported?(module, :__schema__, 0) ->
        encode(value, module.__schema__())

      # If module has to_plutus, use it directly
      function_exported?(module, :to_plutus, 1) ->
        {:ok, module.to_plutus(value)}

      true ->
        {:error,
         {:encode_error, "Module #{inspect(module)} does not have __schema__/0 or to_plutus/1"}}
    end
  end

  # Handle empty schema (pass through as raw data)
  def encode(value, schema, _definitions) when schema == %{} do
    {:ok, value}
  end

  def encode(_value, schema, _definitions) do
    {:error, {:encode_error, "Unsupported schema type: #{inspect(schema)}"}}
  end

  @doc """
  Decodes Plutus data into an Elixir value based on the provided schema.

  ## Parameters

  - `plutus_data` - The Plutus data to decode
  - `schema` - The schema definition (map with schema type info or $ref)
  - `definitions` - Optional map of all definitions from the blueprint (required for $ref)

  ## Returns

  - `{:ok, value}` - Successfully decoded value
  - `{:error, reason}` - Decoding failed

  ## Examples

      # Decode an integer
      iex> Blueprint.decode(42, %{"dataType" => "integer"})
      {:ok, 42}

      # Decode bytes
      iex> Blueprint.decode(<<222, 173, 190, 239>>, %{"dataType" => "bytes"})
      {:ok, <<222, 173, 190, 239>>}

      # Decode a constructor
      iex> schema = %{
      ...>   "anyOf" => [
      ...>     %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => []}
      ...>   ]
      ...> }
      iex> Blueprint.decode(%Constr{index: 0, fields: []}, schema)
      {:ok, %{constructor: "Foo", fields: %{}}}
  """
  @spec decode(Plutus.t(), schema(), definitions()) :: {:ok, any()} | decode_error()
  def decode(plutus_data, schema, definitions \\ %{})

  def decode(plutus_data, %{"$ref" => ref}, definitions) do
    case resolve_ref(ref, definitions) do
      {:ok, resolved_schema} -> decode(plutus_data, resolved_schema, definitions)
      error -> error
    end
  end

  # Handle "anyOf" schemas (constructors/enums)
  def decode(plutus_data, %{"anyOf" => variants}, definitions) do
    decode_constructor(plutus_data, variants, definitions)
  end

  # Handle primitive types
  def decode(plutus_data, %{"dataType" => "bytes"}, _definitions) do
    decode_bytes(plutus_data)
  end

  def decode(plutus_data, %{"dataType" => "integer"}, _definitions) do
    decode_integer(plutus_data)
  end

  # Handle lists with single item schema (homogeneous list)
  def decode(plutus_data, %{"dataType" => "list", "items" => items}, definitions)
      when is_map(items) do
    decode_list(plutus_data, items, definitions)
  end

  # Handle tuples (list with array of item schemas)
  def decode(plutus_data, %{"dataType" => "list", "items" => items}, definitions)
      when is_list(items) do
    decode_tuple(plutus_data, items, definitions)
  end

  # Handle map type
  def decode(
        plutus_data,
        %{"dataType" => "map", "keys" => keys_schema, "values" => values_schema},
        definitions
      ) do
    decode_map(plutus_data, keys_schema, values_schema, definitions)
  end

  # Handle single constructor schema (not wrapped in anyOf)
  def decode(plutus_data, %{"dataType" => "constructor"} = schema, definitions) do
    # Wrap in anyOf and delegate to constructor decoding
    decode_constructor(plutus_data, [schema], definitions)
  end

  # Handle "Data" type (any plutus data - pass through)
  def decode(plutus_data, %{"title" => "Data"}, _definitions) do
    {:ok, plutus_data}
  end

  # Handle module reference - delegate to module's schema/functions
  def decode(plutus_data, %{"$module" => module}, _definitions) when is_atom(module) do
    Code.ensure_loaded(module)

    cond do
      # If module has from_plutus, use it directly (preferred as it returns struct)
      function_exported?(module, :from_plutus, 1) ->
        module.from_plutus(plutus_data)

      # If module has __schema__, use Blueprint with that schema
      function_exported?(module, :__schema__, 0) ->
        decode(plutus_data, module.__schema__())

      true ->
        {:error,
         {:decode_error, "Module #{inspect(module)} does not have __schema__/0 or from_plutus/1"}}
    end
  end

  # Handle empty schema (pass through as raw data)
  def decode(plutus_data, schema, _definitions) when schema == %{} do
    {:ok, plutus_data}
  end

  def decode(_plutus_data, schema, _definitions) do
    {:error, {:decode_error, "Unsupported schema type: #{inspect(schema)}"}}
  end

  # ============================================================================
  # Reference Resolution
  # ============================================================================

  defp resolve_ref("#/definitions/" <> path, definitions) do
    # Handle URL-encoded paths (e.g., "cardano~1assets~1PolicyId" -> "cardano/assets/PolicyId")
    decoded_path = URI.decode(path) |> String.replace("~1", "/")

    case Map.get(definitions, decoded_path) || Map.get(definitions, path) do
      nil -> {:error, {:encode_error, "Definition not found: #{path}"}}
      schema -> {:ok, schema}
    end
  end

  defp resolve_ref(ref, _definitions) do
    {:error, {:encode_error, "Invalid reference format: #{ref}"}}
  end

  # ============================================================================
  # Encoding Helpers
  # ============================================================================

  defp encode_bytes(value) when is_binary(value) do
    # Try to decode as hex first, otherwise use raw bytes
    case Base.decode16(value, case: :mixed) do
      {:ok, bytes} -> {:ok, %CBOR.Tag{tag: :bytes, value: bytes}}
      :error -> {:ok, %CBOR.Tag{tag: :bytes, value: value}}
    end
  end

  defp encode_bytes(%CBOR.Tag{tag: :bytes} = tag), do: {:ok, tag}

  defp encode_bytes(value) do
    {:error, {:encode_error, "Expected binary for bytes type, got: #{inspect(value)}"}}
  end

  defp encode_integer(value) when is_integer(value), do: {:ok, value}

  defp encode_integer(value) do
    {:error, {:encode_error, "Expected integer, got: #{inspect(value)}"}}
  end

  defp encode_list(values, item_schema, definitions) when is_list(values) do
    results =
      Enum.reduce_while(values, {:ok, []}, fn v, {:ok, acc} ->
        case encode(v, item_schema, definitions) do
          {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, encoded_list} -> {:ok, %PList{value: Enum.reverse(encoded_list)}}
      error -> error
    end
  end

  defp encode_list(value, _item_schema, _definitions) do
    {:error, {:encode_error, "Expected list, got: #{inspect(value)}"}}
  end

  defp encode_tuple(values, item_schemas, definitions) when is_list(values) or is_tuple(values) do
    values_list = if is_tuple(values), do: Tuple.to_list(values), else: values

    if length(values_list) != length(item_schemas) do
      {:error,
       {:encode_error,
        "Tuple size mismatch: expected #{length(item_schemas)}, got #{length(values_list)}"}}
    else
      results =
        Enum.zip(values_list, item_schemas)
        |> Enum.reduce_while({:ok, []}, fn {v, schema}, {:ok, acc} ->
          case encode(v, schema, definitions) do
            {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
            error -> {:halt, error}
          end
        end)

      case results do
        {:ok, encoded_list} -> {:ok, %PList{value: Enum.reverse(encoded_list)}}
        error -> error
      end
    end
  end

  defp encode_tuple(value, _item_schemas, _definitions) do
    {:error, {:encode_error, "Expected list or tuple, got: #{inspect(value)}"}}
  end

  defp encode_map(value, keys_schema, values_schema, definitions) when is_map(value) do
    results =
      Enum.reduce_while(value, {:ok, []}, fn {k, v}, {:ok, acc} ->
        with {:ok, encoded_key} <- encode(k, keys_schema, definitions),
             {:ok, encoded_value} <- encode(v, values_schema, definitions) do
          {:cont, {:ok, [{encoded_key, encoded_value} | acc]}}
        else
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, pairs} -> {:ok, Enum.reverse(pairs)}
      error -> error
    end
  end

  defp encode_map(value, _keys_schema, _values_schema, _definitions) do
    {:error, {:encode_error, "Expected map, got: #{inspect(value)}"}}
  end

  defp encode_constructor(value, variants, definitions) do
    # Special handling for nil - look for None variant (Option type)
    if is_nil(value) do
      case Enum.find(variants, fn v -> v["title"] == "None" end) do
        nil ->
          {:error, {:encode_error, "Got nil but no None constructor found"}}

        none_variant ->
          {:ok, %Constr{index: none_variant["index"], fields: []}}
      end
    else
      # Handle Option Some - if we have a raw value and there's a Some variant
      some_variant = Enum.find(variants, fn v -> v["title"] == "Some" end)

      value_to_encode =
        if some_variant && !is_map(value) do
          # Wrap raw value as Some
          [schema] = some_variant["fields"] || []

          case encode(value, schema, definitions) do
            {:ok, encoded} -> {:ok, %Constr{index: some_variant["index"], fields: [encoded]}}
            error -> error
          end
        else
          nil
        end

      case value_to_encode do
        {:ok, _} = result ->
          result

        {:error, _} = error ->
          error

        nil ->
          case find_matching_variant(value, variants) do
            {:ok, variant, index, field_values} ->
              encode_constructor_fields(variant, index, field_values, definitions)

            {:error, _} = error ->
              error
          end
      end
    end
  end

  defp find_matching_variant(%{constructor: constructor_name} = value, variants) do
    case Enum.find_index(variants, fn v -> v["title"] == to_string(constructor_name) end) do
      nil ->
        {:error, {:encode_error, "No matching constructor found for: #{constructor_name}"}}

      _idx ->
        variant = Enum.find(variants, fn v -> v["title"] == to_string(constructor_name) end)
        fields = Map.get(value, :fields, %{})
        {:ok, variant, variant["index"], fields}
    end
  end

  # Support for simple atom/string constructor names for unit constructors
  defp find_matching_variant(constructor_name, variants)
       when is_atom(constructor_name) or is_binary(constructor_name) do
    name = to_string(constructor_name)

    case Enum.find(variants, fn v -> v["title"] == name end) do
      nil ->
        {:error, {:encode_error, "No matching constructor found for: #{name}"}}

      variant ->
        if variant["fields"] == [] do
          {:ok, variant, variant["index"], %{}}
        else
          {:error, {:encode_error, "Constructor #{name} requires fields, but none provided"}}
        end
    end
  end

  # Support for constructor by index
  defp find_matching_variant({:constr, index, fields}, variants) when is_integer(index) do
    case Enum.find(variants, fn v -> v["index"] == index end) do
      nil ->
        {:error, {:encode_error, "No constructor with index: #{index}"}}

      variant ->
        {:ok, variant, index, fields}
    end
  end

  defp find_matching_variant(value, _variants) do
    {:error,
     {:encode_error,
      "Invalid constructor value format. Expected %{constructor: name, fields: ...}, got: #{inspect(value)}"}}
  end

  defp encode_constructor_fields(variant, index, field_values, definitions) do
    field_schemas = variant["fields"] || []

    if field_schemas == [] and (field_values == %{} or field_values == [] or field_values == nil) do
      {:ok, %Constr{index: index, fields: []}}
    else
      encoded_fields = encode_fields(field_values, field_schemas, definitions)

      case encoded_fields do
        {:ok, fields} -> {:ok, %Constr{index: index, fields: fields}}
        error -> error
      end
    end
  end

  defp encode_fields(field_values, field_schemas, definitions) when is_map(field_values) do
    # Named fields - match by title
    results =
      Enum.reduce_while(field_schemas, {:ok, []}, fn schema, {:ok, acc} ->
        field_name = schema["title"]

        field_value =
          Map.get(field_values, field_name) || Map.get(field_values, String.to_atom(field_name))

        case encode(field_value, schema, definitions) do
          {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, fields} -> {:ok, Enum.reverse(fields)}
      error -> error
    end
  end

  defp encode_fields(field_values, field_schemas, definitions) when is_list(field_values) do
    # Positional fields
    if length(field_values) != length(field_schemas) do
      {:error,
       {:encode_error,
        "Field count mismatch: expected #{length(field_schemas)}, got #{length(field_values)}"}}
    else
      results =
        Enum.zip(field_values, field_schemas)
        |> Enum.reduce_while({:ok, []}, fn {value, schema}, {:ok, acc} ->
          case encode(value, schema, definitions) do
            {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
            error -> {:halt, error}
          end
        end)

      case results do
        {:ok, fields} -> {:ok, Enum.reverse(fields)}
        error -> error
      end
    end
  end

  # ============================================================================
  # Decoding Helpers
  # ============================================================================

  # Decode bytes returns hex-encoded string for consistency with defdata behavior
  defp decode_bytes(%CBOR.Tag{tag: :bytes, value: value}),
    do: {:ok, Base.encode16(value, case: :lower)}

  defp decode_bytes(value) when is_binary(value),
    do: {:ok, Base.encode16(value, case: :lower)}

  defp decode_bytes(value) do
    {:error, {:decode_error, "Expected bytes, got: #{inspect(value)}"}}
  end

  defp decode_integer(value) when is_integer(value), do: {:ok, value}

  defp decode_integer(value) do
    {:error, {:decode_error, "Expected integer, got: #{inspect(value)}"}}
  end

  defp decode_list(%PList{value: values}, item_schema, definitions) do
    decode_list(values, item_schema, definitions)
  end

  defp decode_list(values, item_schema, definitions) when is_list(values) do
    results =
      Enum.reduce_while(values, {:ok, []}, fn v, {:ok, acc} ->
        case decode(v, item_schema, definitions) do
          {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, decoded_list} -> {:ok, Enum.reverse(decoded_list)}
      error -> error
    end
  end

  defp decode_list(value, _item_schema, _definitions) do
    {:error, {:decode_error, "Expected list or PList, got: #{inspect(value)}"}}
  end

  defp decode_tuple(%PList{value: values}, item_schemas, definitions) do
    decode_tuple(values, item_schemas, definitions)
  end

  defp decode_tuple(values, item_schemas, definitions) when is_list(values) do
    if length(values) != length(item_schemas) do
      {:error,
       {:decode_error,
        "Tuple size mismatch: expected #{length(item_schemas)}, got #{length(values)}"}}
    else
      results =
        Enum.zip(values, item_schemas)
        |> Enum.reduce_while({:ok, []}, fn {v, schema}, {:ok, acc} ->
          case decode(v, schema, definitions) do
            {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
            error -> {:halt, error}
          end
        end)

      case results do
        # Return Elixir tuple, not list
        {:ok, decoded_list} -> {:ok, List.to_tuple(Enum.reverse(decoded_list))}
        error -> error
      end
    end
  end

  defp decode_tuple(value, _item_schemas, _definitions) do
    {:error, {:decode_error, "Expected list, PList or tuple, got: #{inspect(value)}"}}
  end

  defp decode_map(pairs, keys_schema, values_schema, definitions) when is_list(pairs) do
    results =
      Enum.reduce_while(pairs, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
        with {:ok, decoded_key} <- decode(k, keys_schema, definitions),
             {:ok, decoded_value} <- decode(v, values_schema, definitions) do
          {:cont, {:ok, Map.put(acc, decoded_key, decoded_value)}}
        else
          error -> {:halt, error}
        end
      end)

    results
  end

  defp decode_map(value, _keys_schema, _values_schema, _definitions) do
    {:error, {:decode_error, "Expected list of pairs for map, got: #{inspect(value)}"}}
  end

  defp decode_constructor(%Constr{index: index, fields: fields}, variants, definitions) do
    case Enum.find(variants, fn v -> v["index"] == index end) do
      nil ->
        {:error, {:decode_error, "No constructor with index: #{index}"}}

      variant ->
        decode_constructor_fields(variant, fields, definitions)
    end
  end

  defp decode_constructor(value, _variants, _definitions) do
    {:error, {:decode_error, "Expected Constr, got: #{inspect(value)}"}}
  end

  defp decode_constructor_fields(variant, fields, definitions) do
    field_schemas = variant["fields"] || []
    title = variant["title"]

    # Handle Option type specially - unwrap Some/None
    case title do
      "None" ->
        {:ok, nil}

      "Some" when length(field_schemas) == 1 ->
        [value] = fields
        [schema] = field_schemas
        decode(value, schema, definitions)

      _ ->
        if field_schemas == [] do
          {:ok, %{constructor: title, fields: %{}}}
        else
          if length(fields) != length(field_schemas) do
            {:error,
             {:decode_error,
              "Field count mismatch for #{title}: expected #{length(field_schemas)}, got #{length(fields)}"}}
          else
            decoded_fields = decode_fields(fields, field_schemas, definitions)

            case decoded_fields do
              {:ok, field_map} -> {:ok, %{constructor: title, fields: field_map}}
              error -> error
            end
          end
        end
    end
  end

  defp decode_fields(field_values, field_schemas, definitions) do
    results =
      Enum.zip(field_values, field_schemas)
      |> Enum.reduce_while({:ok, %{}}, fn {value, schema}, {:ok, acc} ->
        field_name = schema["title"]

        case decode(value, schema, definitions) do
          {:ok, decoded} ->
            key = if field_name, do: field_name, else: map_size(acc)
            {:cont, {:ok, Map.put(acc, key, decoded)}}

          error ->
            {:halt, error}
        end
      end)

    results
  end
end
