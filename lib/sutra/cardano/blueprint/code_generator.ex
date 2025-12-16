defmodule Sutra.Cardano.Blueprint.CodeGenerator do
  @moduledoc """
  Generates Elixir modules and structs from CIP-57 Blueprint schemas.

  This module transforms resolved blueprint schemas into Elixir source code,
  creating:
  - Datum module with typed structs and encode/decode functions
  - Redeemer module with simple functions for transaction building
  - Validator metadata (hash, compiled code)

  Uses EEx templates stored in `priv/blueprint_generator/` for cleaner code generation.
  """

  alias Sutra.Cardano.Blueprint.Parser

  @type generate_opts :: [
          only_title: String.t() | nil,
          only_spend: boolean(),
          only_mint: boolean(),
          only_withdraw: boolean(),
          only_publish: boolean(),
          only_vote: boolean()
        ]

  # ============================================================================
  # Template Loading
  # ============================================================================

  # Compile templates at compile time for better performance
  @module_template File.read!(Path.join(:code.priv_dir(:sutra), "blueprint_generator/module.eex"))
  @redeemer_template File.read!(
                       Path.join(:code.priv_dir(:sutra), "blueprint_generator/redeemer.eex")
                     )
  @datum_template File.read!(Path.join(:code.priv_dir(:sutra), "blueprint_generator/datum.eex"))
  @unit_module_template File.read!(
                          Path.join(:code.priv_dir(:sutra), "blueprint_generator/unit_module.eex")
                        )
  @record_module_template File.read!(
                            Path.join(
                              :code.priv_dir(:sutra),
                              "blueprint_generator/record_module.eex"
                            )
                          )
  @redeemer_simple_template File.read!(
                              Path.join(
                                :code.priv_dir(:sutra),
                                "blueprint_generator/redeemer_simple.eex"
                              )
                            )

  # Mark external resources so module recompiles when templates change
  @external_resource Path.join(:code.priv_dir(:sutra), "blueprint_generator/module.eex")
  @external_resource Path.join(:code.priv_dir(:sutra), "blueprint_generator/redeemer.eex")
  @external_resource Path.join(:code.priv_dir(:sutra), "blueprint_generator/redeemer_simple.eex")
  @external_resource Path.join(:code.priv_dir(:sutra), "blueprint_generator/datum.eex")
  @external_resource Path.join(:code.priv_dir(:sutra), "blueprint_generator/unit_module.eex")
  @external_resource Path.join(:code.priv_dir(:sutra), "blueprint_generator/record_module.eex")

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Generates Elixir module source code from a blueprint.

  ## Parameters

  - `blueprint` - The parsed blueprint JSON
  - `module_name` - The base module name to generate (e.g., "MyApp.Contracts")
  - `opts` - Generation options

  ## Options

  - `:only_title` - Only generate for validators starting with this title prefix
  - `:only_spend` - Only generate for spend validators
  - `:only_mint` - Only generate for mint validators
  - `:only_withdraw` - Only generate for withdraw validators
  - `:only_publish` - Only generate for publish validators
  - `:only_vote` - Only generate for vote validators

  ## Returns

  A map of `%{module_name => source_code}` for each generated module.
  """
  @spec generate(map(), String.t(), generate_opts()) ::
          {:ok, %{String.t() => String.t()}} | {:error, any()}
  def generate(blueprint, module_name, opts \\ []) do
    case Parser.parse_validators(blueprint) do
      {:ok, validators} ->
        filtered = filter_validators(validators, opts)
        modules = generate_modules(filtered, module_name, blueprint["definitions"] || %{})
        {:ok, modules}

      error ->
        error
    end
  end

  @doc """
  Returns the path to the templates directory.
  """
  def templates_dir do
    Path.join(:code.priv_dir(:sutra), "blueprint_generator")
  end

  # ============================================================================
  # Validator Filtering
  # ============================================================================

  defp filter_validators(validators, opts) do
    validators
    |> filter_by_title(opts[:only_title])
    |> filter_by_type(opts)
  end

  defp filter_by_title(validators, nil), do: validators

  defp filter_by_title(validators, prefix) do
    Enum.filter(validators, fn v ->
      String.starts_with?(v.title, prefix)
    end)
  end

  defp filter_by_type(validators, opts) do
    type_filters = [
      {:only_spend, ".spend"},
      {:only_mint, ".mint"},
      {:only_withdraw, ".withdraw"},
      {:only_publish, ".publish"},
      {:only_vote, ".vote"}
    ]

    active_filters =
      Enum.filter(type_filters, fn {key, _suffix} -> opts[key] end)
      |> Enum.map(fn {_key, suffix} -> suffix end)

    if active_filters == [] do
      validators
    else
      Enum.filter(validators, fn v ->
        Enum.any?(active_filters, fn suffix -> String.ends_with?(v.title, suffix) end)
      end)
    end
  end

  # ============================================================================
  # Module Generation
  # ============================================================================

  defp generate_modules(validators, base_module, definitions) do
    grouped =
      Enum.group_by(validators, fn v ->
        v.title
        |> String.split(".")
        |> Enum.drop(-1)
        |> Enum.join(".")
      end)

    Enum.reduce(grouped, %{}, fn {validator_base, group_validators}, acc ->
      module_name = validator_module_name(base_module, validator_base)
      source = generate_validator_module(module_name, group_validators, definitions)
      Map.put(acc, module_name, source)
    end)
  end

  defp validator_module_name(base_module, validator_base) do
    parts =
      validator_base
      |> String.split(".")
      |> Enum.map(&Macro.camelize/1)
      |> Enum.join(".")

    "#{base_module}.#{parts}"
  end

  defp generate_validator_module(module_name, validators, _definitions) do
    # Find spend validator for datum (datum only exists on spend validators)
    spend_validator = Enum.find(validators, fn v -> String.ends_with?(v.title, ".spend") end)

    # Generate datum module if spend validator has a datum schema
    datum_module =
      if spend_validator && spend_validator.datum_schema do
        generate_datum_module(spend_validator.datum_schema)
      else
        ""
      end

    # Generate redeemer modules for each validator purpose (except else)
    redeemer_modules =
      validators
      |> Enum.reject(fn v -> String.ends_with?(v.title, ".else") end)
      |> Enum.filter(fn v -> v.redeemer_schema != nil end)
      |> Enum.map(fn v ->
        purpose = validator_type(v.title)
        module_name = "Redeemer#{purpose |> Atom.to_string() |> Macro.camelize()}"
        generate_redeemer_module(v.redeemer_schema, module_name, purpose)
      end)
      |> Enum.join("\n\n")

    # Get hash and compiled code from first validator (they're all the same)
    first_validator = hd(validators)
    hash = first_validator.hash || ""
    compiled_code = first_validator.compiled_code || ""

    EEx.eval_string(@module_template,
      assigns: [
        module_name: module_name,
        hash: hash,
        compiled_code: compiled_code,
        datum_module: datum_module,
        redeemer_modules: redeemer_modules
      ]
    )
  end

  # ============================================================================
  # Redeemer Module Generation
  # ============================================================================

  defp generate_redeemer_module(%{"anyOf" => variants} = schema, module_name, purpose) do
    # Build variant info for the template
    variant_infos =
      Enum.map(variants, fn variant ->
        fields = variant["fields"] || []

        field_args = generate_redeemer_field_args(fields)
        field_map = generate_redeemer_field_map(fields)

        %{
          title: variant["title"],
          index: variant["index"],
          fields: fields,
          field_args: field_args,
          field_map: field_map
        }
      end)

    EEx.eval_string(@redeemer_template,
      assigns: [
        module_name: module_name,
        purpose: purpose,
        schema: schema,
        variants: variant_infos
      ]
    )
  end

  # Handle list type redeemers (like WithdrawSignatures which is a list of tuples)
  defp generate_redeemer_module(%{"dataType" => "list"} = schema, module_name, purpose) do
    title = schema["title"] || "List"
    func_name = title |> Macro.underscore()

    EEx.eval_string(@redeemer_simple_template,
      assigns: [
        module_name: module_name,
        purpose: purpose,
        schema: schema,
        title: title,
        func_name: func_name
      ]
    )
  end

  # Handle constructor type redeemers (single constructor)
  defp generate_redeemer_module(%{"dataType" => "constructor"} = schema, module_name, purpose) do
    # Treat as a single-variant enum
    generate_redeemer_module(%{"anyOf" => [schema]}, module_name, purpose)
  end

  # Skip Data type (any plutus data) and empty schemas
  defp generate_redeemer_module(%{"title" => "Data"}, _module_name, _purpose), do: ""
  defp generate_redeemer_module(_schema, _module_name, _purpose), do: ""

  defp generate_redeemer_field_args(fields) do
    fields
    |> Enum.with_index()
    |> Enum.map(fn {f, idx} ->
      name = f["title"] || "field_#{idx}"
      Macro.underscore(name)
    end)
    |> Enum.join(", ")
  end

  defp generate_redeemer_field_map(fields) do
    fields
    |> Enum.with_index()
    |> Enum.map(fn {f, idx} ->
      name = f["title"] || "field_#{idx}"
      arg_name = Macro.underscore(name)
      "\"#{name}\" => #{arg_name}"
    end)
    |> Enum.join(", ")
  end

  # ============================================================================
  # Datum Module Generation
  # ============================================================================

  defp generate_datum_module(%{"anyOf" => variants}) when length(variants) == 1 do
    # Single constructor - generate as a simple struct
    [variant] = variants
    generate_datum_struct(variant)
  end

  defp generate_datum_module(%{"anyOf" => variants}) do
    # Multiple constructors - generate as enum with variant submodules
    variant_modules =
      variants
      |> Enum.map(fn variant ->
        generate_datum_variant_module(variant)
      end)
      |> Enum.join("\n\n")

    type_union = Enum.map_join(variants, " | ", fn v -> v["title"] <> ".t()" end)

    EEx.eval_string(@datum_template,
      assigns: [
        is_enum: true,
        variants: variants,
        type_union: type_union,
        variant_modules: variant_modules
      ]
    )
  end

  defp generate_datum_module(%{"dataType" => "constructor"} = schema) do
    generate_datum_struct(schema)
  end

  # Handle "Data" type - any plutus data, no specific structure
  defp generate_datum_module(%{"title" => "Data"}), do: ""
  defp generate_datum_module(_), do: ""

  defp generate_datum_struct(%{"fields" => fields, "index" => index}) when is_list(fields) do
    if fields == [] do
      # Unit datum (no fields)
      EEx.eval_string(@datum_template,
        assigns: [
          is_enum: false,
          struct_fields: [],
          field_types: "",
          to_plutus_fields: "",
          from_plutus_fields: "",
          field_pattern: "",
          index: index
        ]
      )
    else
      field_names = extract_field_names(fields)
      struct_fields = Enum.map(field_names, &String.to_atom/1)

      EEx.eval_string(@datum_template,
        assigns: [
          is_enum: false,
          struct_fields: struct_fields,
          field_types: generate_field_types(fields),
          to_plutus_fields: generate_to_plutus_fields(fields),
          from_plutus_fields: generate_from_plutus_fields(fields),
          field_pattern: generate_field_pattern(fields),
          index: index
        ]
      )
    end
  end

  defp generate_datum_struct(_), do: ""

  defp generate_datum_variant_module(%{"fields" => fields, "index" => index, "title" => title})
       when is_list(fields) do
    if fields == [] do
      EEx.eval_string(@unit_module_template,
        assigns: [
          name: title,
          index: index
        ]
      )
    else
      field_names = extract_field_names(fields)
      struct_fields = Enum.map(field_names, &String.to_atom/1)

      EEx.eval_string(@record_module_template,
        assigns: [
          name: title,
          index: index,
          struct_fields: struct_fields,
          field_types: generate_field_types(fields),
          to_plutus_fields: generate_to_plutus_fields(fields),
          from_plutus_fields: generate_from_plutus_fields(fields),
          field_pattern: generate_field_pattern(fields)
        ]
      )
    end
  end

  defp generate_datum_variant_module(_), do: ""

  # ============================================================================
  # Field Helpers
  # ============================================================================

  defp extract_field_names(fields) do
    Enum.with_index(fields)
    |> Enum.map(fn {f, idx} ->
      f["title"] || "field_#{idx}"
    end)
  end

  defp generate_field_types(fields) do
    Enum.with_index(fields)
    |> Enum.map(fn {f, idx} ->
      name = f["title"] || "field_#{idx}"
      type = field_type_spec(f)
      "      #{name}: #{type}"
    end)
    |> Enum.join(",\n")
  end

  defp field_type_spec(%{"dataType" => "integer"}), do: "integer()"
  defp field_type_spec(%{"dataType" => "bytes"}), do: "binary()"

  defp field_type_spec(%{"dataType" => "list", "items" => items}) when is_map(items) do
    "[#{field_type_spec(items)}]"
  end

  defp field_type_spec(%{"anyOf" => _} = schema) do
    if schema["title"], do: "#{schema["title"]}.t()", else: "term()"
  end

  defp field_type_spec(_), do: "term()"

  defp generate_field_pattern(fields) do
    Enum.map_join(0..(length(fields) - 1), ", ", fn i -> "f#{i}" end)
  end

  defp generate_to_plutus_fields(fields) do
    Enum.with_index(fields)
    |> Enum.map(fn {f, idx} ->
      name = f["title"] || "field_#{idx}"
      atom_name = String.to_atom(name)
      encode_expr = field_to_plutus(f, "data.#{atom_name}")
      "        #{encode_expr}"
    end)
    |> Enum.join(",\n")
  end

  defp field_to_plutus(%{"dataType" => "bytes"}, expr) do
    "%CBOR.Tag{tag: :bytes, value: #{expr}}"
  end

  defp field_to_plutus(%{"dataType" => "integer"}, expr), do: expr

  defp field_to_plutus(%{"dataType" => "list", "items" => items}, expr) when is_map(items) do
    inner = field_to_plutus(items, "v")
    "%PList{value: Enum.map(#{expr}, fn v -> #{inner} end)}"
  end

  defp field_to_plutus(%{"anyOf" => _}, expr) do
    "#{expr}.__struct__.to_plutus(#{expr})"
  end

  defp field_to_plutus(_, expr), do: expr

  defp generate_from_plutus_fields(fields) do
    Enum.with_index(fields)
    |> Enum.map(fn {f, idx} ->
      name = f["title"] || "field_#{idx}"
      atom_name = String.to_atom(name)
      decode_expr = field_from_plutus(f, "f#{idx}")
      "          #{atom_name}: #{decode_expr}"
    end)
    |> Enum.join(",\n")
  end

  defp field_from_plutus(%{"dataType" => "bytes"}, expr) do
    "case #{expr} do %CBOR.Tag{tag: :bytes, value: v} -> v; v -> v end"
  end

  defp field_from_plutus(%{"dataType" => "integer"}, expr), do: expr

  defp field_from_plutus(%{"dataType" => "list", "items" => items}, expr) when is_map(items) do
    inner = field_from_plutus(items, "v")

    "case #{expr} do %PList{value: l} -> Enum.map(l, fn v -> #{inner} end); l -> l end"
  end

  defp field_from_plutus(_, expr), do: expr

  # ============================================================================
  # Helpers
  # ============================================================================

  @doc """
  Determines the validator type from its title.
  """
  def validator_type(title) do
    cond do
      String.ends_with?(title, ".spend") -> :spend
      String.ends_with?(title, ".mint") -> :mint
      String.ends_with?(title, ".withdraw") -> :withdraw
      String.ends_with?(title, ".publish") -> :publish
      String.ends_with?(title, ".vote") -> :vote
      String.ends_with?(title, ".else") -> :else
      true -> :unknown
    end
  end
end
