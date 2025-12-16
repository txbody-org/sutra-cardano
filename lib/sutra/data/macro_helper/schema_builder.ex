defmodule Sutra.Data.MacroHelper.SchemaBuilder do
  @moduledoc """
  Builds CIP-57 Blueprint schemas from Elixir type declarations.

  This module converts the type declarations used in `defdata` and `defenum`
  into Blueprint-compatible schema maps that can be used with
  `Sutra.Cardano.Blueprint.encode/2` and `decode/2`.
  """

  alias Sutra.Data.Option

  @doc """
  Builds a Blueprint schema for an object (constructor with fields).

  ## Example

      iex> SchemaBuilder.build_object_schema(MyModule, [
      ...>   {:transaction_id, %{"dataType" => "bytes"}},
      ...>   {:output_index, %{"dataType" => "integer"}}
      ...> ])
      %{
        "title" => "MyModule",
        "dataType" => "constructor",
        "index" => 0,
        "fields" => [
          %{"title" => "transaction_id", "dataType" => "bytes"},
          %{"title" => "output_index", "dataType" => "integer"}
        ]
      }
  """
  def build_object_schema(module, field_schemas) do
    title = module |> Module.split() |> List.last()

    fields =
      Enum.map(field_schemas, fn {name, schema} ->
        Map.put(schema, "title", to_string(name))
      end)

    %{
      "title" => title,
      "dataType" => "constructor",
      "index" => 0,
      "fields" => fields
    }
  end

  @doc """
  Builds a Blueprint schema for an enum (anyOf with multiple constructors).

  ## Example

      iex> SchemaBuilder.build_enum_schema(MyEnum, [
      ...>   {:variant_a, 0, %{"dataType" => "bytes"}},
      ...>   {:variant_b, 1, nil}
      ...> ])
      %{
        "title" => "MyEnum",
        "anyOf" => [
          %{"title" => "VariantA", "dataType" => "constructor", "index" => 0, "fields" => [...]},
          %{"title" => "VariantB", "dataType" => "constructor", "index" => 1, "fields" => []}
        ]
      }
  """
  def build_enum_schema(module, variants) do
    title = module |> Module.split() |> List.last()

    any_of =
      Enum.map(variants, fn {name, index, field_schema} ->
        variant_title =
          name
          |> to_string()
          |> Macro.camelize()

        fields =
          case field_schema do
            nil ->
              []

            # Tuple type - expand to multiple positional fields
            %{"dataType" => "list", "items" => items} when is_list(items) ->
              items
              |> Enum.with_index()
              |> Enum.map(fn {item_schema, idx} ->
                Map.put(item_schema, "title", "field_#{idx}")
              end)

            %{"dataType" => _} ->
              [Map.put(field_schema, "title", "value")]

            schema when is_map(schema) ->
              [Map.put(schema, "title", "value")]
          end

        %{
          "title" => variant_title,
          "dataType" => "constructor",
          "index" => index,
          "fields" => fields
        }
      end)

    %{
      "title" => title,
      "anyOf" => any_of
    }
  end

  @doc """
  Converts an Elixir type declaration to a Blueprint schema.

  Supports:
  - `:string` / `:bytes` -> bytes
  - `:integer` -> integer
  - `:null` -> null/unit constructor
  - `{:list, type}` -> list
  - `{type1, type2, ...}` -> tuple (list with fixed items)
  - `%Option{option: type}` -> optional (anyOf with None/Some)
  - Module name -> reference to module's schema
  """
  def type_to_schema(:string), do: %{"dataType" => "bytes", "title" => "ByteArray"}
  def type_to_schema(:bytes), do: %{"dataType" => "bytes", "title" => "ByteArray"}
  def type_to_schema(:integer), do: %{"dataType" => "integer", "title" => "Int"}
  # :null means no field (empty constructor)
  def type_to_schema(:null), do: nil

  # List type
  def type_to_schema({:list, item_type}) do
    %{
      "dataType" => "list",
      "items" => type_to_schema(item_type)
    }
  end

  # Tuple type (fixed-length list)
  def type_to_schema(tuple) when is_tuple(tuple) do
    items =
      tuple
      |> Tuple.to_list()
      |> Enum.map(&type_to_schema/1)

    %{
      "dataType" => "list",
      "items" => items,
      "title" => "Tuple"
    }
  end

  # Option type
  def type_to_schema(%Option{option: inner_type}) do
    inner_schema = type_to_schema(inner_type)

    %{
      "title" => "Option",
      "anyOf" => [
        %{
          "title" => "Some",
          "dataType" => "constructor",
          "index" => 0,
          "fields" => [Map.put(inner_schema, "title", "value")]
        },
        %{
          "title" => "None",
          "dataType" => "constructor",
          "index" => 1,
          "fields" => []
        }
      ]
    }
  end

  # Module reference - the module should have a __schema__ function
  def type_to_schema(module) when is_atom(module) do
    case Atom.to_string(module) do
      "Elixir." <> _ ->
        # It's a module - reference its schema
        # We'll use a marker that we can resolve at runtime
        %{"$module" => module}

      _ ->
        # Unknown atom type
        raise ArgumentError, "Unsupported type: #{inspect(module)}"
    end
  end

  # Keyword list for field info (legacy support)
  def type_to_schema(field_kind: type), do: type_to_schema(type)

  def type_to_schema(type) do
    raise ArgumentError, "Unsupported type for schema conversion: #{inspect(type)}"
  end
end
