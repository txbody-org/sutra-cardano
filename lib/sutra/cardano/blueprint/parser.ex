defmodule Sutra.Cardano.Blueprint.Parser do
  @moduledoc """
  Parser for CIP-57 Blueprint schemas that resolves all `$ref` references recursively.

  This module provides functionality to:
  - Parse a blueprint JSON file and extract validator schemas
  - Resolve all `$ref` references recursively to produce a self-contained schema
  - The resolved schema can be used directly with `Blueprint.encode/2` and `Blueprint.decode/2`
    without needing to pass definitions separately

  ## Example

      # Load and parse a blueprint
      {:ok, blueprint_json} = File.read("plutus.json")
      {:ok, blueprint} = Jason.decode(blueprint_json)

      # Resolve a redeemer schema
      redeemer_schema = %{"$ref" => "#/definitions/nuvola/types/LendingRedeemer"}
      {:ok, resolved} = Parser.resolve_schema(redeemer_schema, blueprint["definitions"])

      # Now encode/decode without passing definitions
      {:ok, plutus_data} = Blueprint.encode(%{constructor: "CreateLend"}, resolved)
      {:ok, decoded} = Blueprint.decode(plutus_data, resolved)

  ## Extracting Validator Schemas

      # Parse validators from blueprint
      {:ok, validators} = Parser.parse_validators(blueprint)

      # Each validator has resolved datum and redeemer schemas
      %{
        title: "lending.lending_validator.spend",
        datum_schema: %{...},      # Fully resolved, no $refs
        redeemer_schema: %{...},   # Fully resolved, no $refs
        parameters: [...]
      }
  """

  @type definitions :: %{String.t() => map()}
  @type schema :: map()
  @type validator_info :: %{
          title: String.t(),
          datum_schema: schema() | nil,
          redeemer_schema: schema() | nil,
          parameters: [map()],
          compiled_code: String.t() | nil,
          hash: String.t() | nil
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Parses a blueprint and extracts all validators with their resolved schemas.

  ## Parameters

  - `blueprint` - The parsed blueprint JSON (as a map)

  ## Returns

  - `{:ok, validators}` - List of validator info maps with resolved schemas
  - `{:error, reason}` - Parsing failed

  ## Example

      {:ok, blueprint} = Jason.decode(json)
      {:ok, validators} = Parser.parse_validators(blueprint)

      Enum.each(validators, fn v ->
        IO.puts("Validator: \#{v.title}")
        IO.inspect(v.redeemer_schema, label: "Redeemer")
      end)
  """
  @spec parse_validators(map()) :: {:ok, [validator_info()]} | {:error, any()}
  def parse_validators(%{"validators" => validators, "definitions" => definitions}) do
    parsed =
      Enum.map(validators, fn validator ->
        parse_validator(validator, definitions)
      end)

    errors = Enum.filter(parsed, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, Enum.map(parsed, fn {:ok, v} -> v end)}
    else
      {:error, {:parse_errors, errors}}
    end
  end

  def parse_validators(%{"validators" => validators}) do
    parse_validators(%{"validators" => validators, "definitions" => %{}})
  end

  def parse_validators(_) do
    {:error, :invalid_blueprint_format}
  end

  @doc """
  Parses a single validator and resolves its datum and redeemer schemas.

  ## Parameters

  - `validator` - A validator definition from the blueprint
  - `definitions` - The definitions map from the blueprint

  ## Returns

  - `{:ok, validator_info}` - Parsed validator with resolved schemas
  - `{:error, reason}` - Parsing failed
  """
  @spec parse_validator(map(), definitions()) :: {:ok, validator_info()} | {:error, any()}
  def parse_validator(validator, definitions) do
    title = validator["title"]

    datum_result =
      case validator["datum"] do
        nil -> {:ok, nil}
        %{"schema" => schema} -> resolve_schema(schema, definitions)
        schema -> resolve_schema(schema, definitions)
      end

    redeemer_result =
      case validator["redeemer"] do
        nil -> {:ok, nil}
        %{"schema" => schema} -> resolve_schema(schema, definitions)
        schema -> resolve_schema(schema, definitions)
      end

    parameters_result = resolve_parameters(validator["parameters"] || [], definitions)

    with {:ok, datum_schema} <- datum_result,
         {:ok, redeemer_schema} <- redeemer_result,
         {:ok, parameters} <- parameters_result do
      {:ok,
       %{
         title: title,
         datum_schema: datum_schema,
         redeemer_schema: redeemer_schema,
         parameters: parameters,
         compiled_code: validator["compiledCode"],
         hash: validator["hash"]
       }}
    end
  end

  @doc """
  Resolves all `$ref` references in a schema recursively.

  This function traverses the schema and replaces all `$ref` references with their
  actual definitions, producing a self-contained schema that can be used for
  encoding/decoding without needing the definitions map.

  ## Parameters

  - `schema` - The schema to resolve (may contain `$ref` references)
  - `definitions` - The definitions map from the blueprint

  ## Returns

  - `{:ok, resolved_schema}` - Schema with all refs resolved
  - `{:error, reason}` - Resolution failed (e.g., missing definition)

  ## Example

      definitions = %{
        "Int" => %{"dataType" => "integer"},
        "MyType" => %{
          "anyOf" => [
            %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => [
              %{"$ref" => "#/definitions/Int"}
            ]}
          ]
        }
      }

      schema = %{"$ref" => "#/definitions/MyType"}
      {:ok, resolved} = Parser.resolve_schema(schema, definitions)

      # resolved is now:
      # %{
      #   "anyOf" => [
      #     %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => [
      #       %{"dataType" => "integer"}
      #     ]}
      #   ]
      # }
  """
  @spec resolve_schema(schema(), definitions()) :: {:ok, schema()} | {:error, any()}
  def resolve_schema(schema, definitions) do
    resolve_schema(schema, definitions, MapSet.new())
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  # Resolve with cycle detection to prevent infinite loops
  defp resolve_schema(schema, definitions, visited)

  # Handle $ref - resolve and continue recursively
  defp resolve_schema(%{"$ref" => ref} = schema, definitions, visited) do
    if MapSet.member?(visited, ref) do
      # Return the ref as-is to break the cycle (this is valid for recursive types)
      {:ok, schema}
    else
      case lookup_definition(ref, definitions) do
        {:ok, resolved_def} ->
          new_visited = MapSet.put(visited, ref)
          resolve_schema(resolved_def, definitions, new_visited)

        error ->
          error
      end
    end
  end

  # Handle anyOf (constructors/enums)
  defp resolve_schema(%{"anyOf" => variants} = schema, definitions, visited) do
    case resolve_variants(variants, definitions, visited) do
      {:ok, resolved_variants} ->
        {:ok, Map.put(schema, "anyOf", resolved_variants)}

      error ->
        error
    end
  end

  # Handle list with single item schema
  defp resolve_schema(%{"dataType" => "list", "items" => items} = schema, definitions, visited)
       when is_map(items) do
    case resolve_schema(items, definitions, visited) do
      {:ok, resolved_items} ->
        {:ok, Map.put(schema, "items", resolved_items)}

      error ->
        error
    end
  end

  # Handle tuple (list with array of item schemas)
  defp resolve_schema(%{"dataType" => "list", "items" => items} = schema, definitions, visited)
       when is_list(items) do
    case resolve_list(items, definitions, visited) do
      {:ok, resolved_items} ->
        {:ok, Map.put(schema, "items", resolved_items)}

      error ->
        error
    end
  end

  # Handle map type
  defp resolve_schema(
         %{"dataType" => "map", "keys" => keys, "values" => values} = schema,
         definitions,
         visited
       ) do
    with {:ok, resolved_keys} <- resolve_schema(keys, definitions, visited),
         {:ok, resolved_values} <- resolve_schema(values, definitions, visited) do
      {:ok, schema |> Map.put("keys", resolved_keys) |> Map.put("values", resolved_values)}
    end
  end

  # Handle constructor with fields
  defp resolve_schema(
         %{"dataType" => "constructor", "fields" => fields} = schema,
         definitions,
         visited
       )
       when is_list(fields) do
    case resolve_fields(fields, definitions, visited) do
      {:ok, resolved_fields} ->
        {:ok, Map.put(schema, "fields", resolved_fields)}

      error ->
        error
    end
  end

  # Handle primitive types and other schemas (no resolution needed)
  defp resolve_schema(schema, _definitions, _visited) when is_map(schema) do
    {:ok, schema}
  end

  # Handle nil
  defp resolve_schema(nil, _definitions, _visited) do
    {:ok, nil}
  end

  # Resolve list of variants (for anyOf)
  defp resolve_variants(variants, definitions, visited) do
    results =
      Enum.reduce_while(variants, {:ok, []}, fn variant, {:ok, acc} ->
        case resolve_schema(variant, definitions, visited) do
          {:ok, resolved} -> {:cont, {:ok, [resolved | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  # Resolve list of field schemas
  defp resolve_fields(fields, definitions, visited) do
    results =
      Enum.reduce_while(fields, {:ok, []}, fn field, {:ok, acc} ->
        # Field can have $ref or be a full schema
        resolved_field =
          cond do
            Map.has_key?(field, "$ref") ->
              case resolve_schema(field, definitions, visited) do
                {:ok, resolved} ->
                  # Preserve title if present in original field
                  if field["title"] do
                    {:ok, Map.put(resolved, "title", field["title"])}
                  else
                    {:ok, resolved}
                  end

                error ->
                  error
              end

            true ->
              resolve_schema(field, definitions, visited)
          end

        case resolved_field do
          {:ok, resolved} -> {:cont, {:ok, [resolved | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  # Resolve list of schemas (for tuple items)
  defp resolve_list(items, definitions, visited) do
    results =
      Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
        case resolve_schema(item, definitions, visited) do
          {:ok, resolved} -> {:cont, {:ok, [resolved | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  # Resolve parameters
  defp resolve_parameters(parameters, definitions) do
    results =
      Enum.reduce_while(parameters, {:ok, []}, fn param, {:ok, acc} ->
        case param do
          %{"schema" => schema} = p ->
            case resolve_schema(schema, definitions, MapSet.new()) do
              {:ok, resolved} ->
                {:cont, {:ok, [Map.put(p, "schema", resolved) | acc]}}

              error ->
                {:halt, error}
            end

          p ->
            {:cont, {:ok, [p | acc]}}
        end
      end)

    case results do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  # Look up a definition by reference path
  defp lookup_definition("#/definitions/" <> path, definitions) do
    # Handle URL-encoded paths (e.g., "cardano~1assets~1PolicyId" -> "cardano/assets/PolicyId")
    decoded_path = URI.decode(path) |> String.replace("~1", "/")

    case Map.get(definitions, decoded_path) || Map.get(definitions, path) do
      nil -> {:error, {:definition_not_found, path}}
      schema -> {:ok, schema}
    end
  end

  defp lookup_definition(ref, _definitions) do
    {:error, {:invalid_ref_format, ref}}
  end
end
