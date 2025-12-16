defmodule Mix.Tasks.Sutra.Blueprint.Gen do
  @shortdoc "Generates Elixir modules from a CIP-57 Blueprint file"

  @moduledoc """
  Generates Elixir modules and structs from a CIP-57 Blueprint JSON file.

  ## Usage

      mix sutra.blueprint.gen /path/to/blueprint.json MyApp.Contracts [options]

  ## Arguments

  - `blueprint_path` - Path to the blueprint JSON file
  - `module_name` - Base module name for generated code (e.g., "MyApp.Contracts")

  ## Options

  - `--only-title NAME` - Only generate for validators whose title starts with NAME
  - `--only-spend` - Only generate for spend validators
  - `--only-mint` - Only generate for mint validators
  - `--only-withdraw` - Only generate for withdraw validators
  - `--only-publish` - Only generate for publish validators
  - `--only-vote` - Only generate for vote validators
  - `--output-dir DIR` - Output directory for generated files (default: lib/)

  ## Examples

      # Generate all validators
      mix sutra.blueprint.gen plutus.json MyApp.Contracts

      # Generate only spend validators
      mix sutra.blueprint.gen plutus.json MyApp.Contracts --only-spend

      # Generate only validators starting with "lending"
      mix sutra.blueprint.gen plutus.json MyApp.Contracts --only-title lending

      # Generate to a specific directory
      mix sutra.blueprint.gen plutus.json MyApp.Contracts --output-dir lib/generated

  ## Generated Structure

  For a blueprint with validators like `lvalidator.spend` and
  `lvalidator.mint`, this will generate:

  ```
  lib/my_app/contracts/lending/lending_validator.ex
  ```

  containing a module `MyApp.Contracts.Lending.LendingValidator` with:

  - Typed structs for datum and redeemer types
  - `to_plutus/1` and `from_plutus/1` conversion functions
  - Validator metadata (hash, compiled code)
  """

  use Mix.Task

  alias Sutra.Cardano.Blueprint.CodeGenerator

  @switches [
    only_title: :string,
    only_spend: :boolean,
    only_mint: :boolean,
    only_withdraw: :boolean,
    only_publish: :boolean,
    only_vote: :boolean,
    output_dir: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _invalid} = OptionParser.parse(args, switches: @switches)

    case positional do
      [blueprint_path, module_name] ->
        generate(blueprint_path, module_name, opts)

      [_blueprint_path] ->
        Mix.raise("Missing module name. Usage: mix sutra.blueprint.gen <path> <module_name>")

      [] ->
        Mix.raise(
          "Missing arguments. Usage: mix sutra.blueprint.gen <path> <module_name> [options]"
        )

      _ ->
        Mix.raise(
          "Too many arguments. Usage: mix sutra.blueprint.gen <path> <module_name> [options]"
        )
    end
  end

  defp generate(blueprint_path, module_name, opts) do
    # Validate blueprint path
    unless File.exists?(blueprint_path) do
      Mix.raise("Blueprint file not found: #{blueprint_path}")
    end

    # Read and parse blueprint
    Mix.shell().info("Reading blueprint from #{blueprint_path}...")

    with {:ok, json} <- File.read(blueprint_path),
         {:ok, blueprint} <- Jason.decode(json) do
      generate_modules(blueprint, module_name, opts)
    else
      {:error, %Jason.DecodeError{} = error} ->
        Mix.raise("Failed to parse blueprint JSON: #{Exception.message(error)}")

      {:error, reason} ->
        Mix.raise("Failed to read blueprint: #{inspect(reason)}")
    end
  end

  defp generate_modules(blueprint, module_name, opts) do
    gen_opts = build_gen_opts(opts)
    output_dir = opts[:output_dir] || "lib"

    case CodeGenerator.generate(blueprint, module_name, gen_opts) do
      {:ok, modules} ->
        process_generated_modules(modules, output_dir)

      {:error, reason} ->
        Mix.raise("Failed to generate modules: #{inspect(reason)}")
    end
  end

  defp build_gen_opts(opts) do
    [
      only_title: opts[:only_title],
      only_spend: opts[:only_spend] || false,
      only_mint: opts[:only_mint] || false,
      only_withdraw: opts[:only_withdraw] || false,
      only_publish: opts[:only_publish] || false,
      only_vote: opts[:only_vote] || false
    ]
  end

  defp process_generated_modules(modules, _output_dir) when map_size(modules) == 0 do
    Mix.shell().info("No validators matched the criteria. Nothing generated.")
  end

  defp process_generated_modules(modules, output_dir) do
    Enum.each(modules, fn {mod_name, source} ->
      write_module(mod_name, source, output_dir)
    end)

    Mix.shell().info("\n✅ Generated #{map_size(modules)} module(s)")
  end

  defp write_module(module_name, source, output_dir) do
    # Convert module name to file path
    # e.g., "MyApp.Contracts.Lending.LendingValidator" -> "my_app/contracts/lending/lending_validator.ex"
    relative_path =
      module_name
      |> String.split(".")
      |> Enum.map_join("/", &Macro.underscore/1)

    file_path = Path.join(output_dir, "#{relative_path}.ex")

    # Ensure directory exists
    file_path
    |> Path.dirname()
    |> File.mkdir_p!()

    # Format the source code
    formatted_source =
      try do
        Code.format_string!(source)
      rescue
        _ -> source
      end

    # Write file
    File.write!(file_path, formatted_source)

    Mix.shell().info("  Created: #{file_path}")
  end
end
