# credo:disable-for-this-file Credo.Check.Readability.FunctionNames
defmodule Sutra.Data.Option do
  @moduledoc """
    Common data types
  """
  @enforce_keys [:option]
  defstruct [:option]

  @type t() :: %__MODULE__{option: atom() | module() | tuple()}

  def sigil_OPTION(params, _modifier) do
    term =
      params
      |> String.trim()
      |> parse_term()

    # Return the struct with the parsed term
    %__MODULE__{option: term}
  end

  defp parse_term(":" <> v), do: String.to_existing_atom(v)

  # Parse the input string into an Elixir term
  defp parse_term(clean_string) do
    # Remove whitespace for consistent parsing

    cond do
      # Handle module names (not starting with :)
      Regex.match?(~r/^[A-Z][a-zA-Z0-9_\.]*$/, clean_string) ->
        String.to_existing_atom("Elixir." <> clean_string)

      # Handle tuples
      String.starts_with?(clean_string, "{") && String.ends_with?(clean_string, "}") ->
        # Extract the content inside the braces
        content =
          clean_string
          |> String.replace_prefix("{", "")
          |> String.replace_suffix("}", "")

        # Split by commas, but respect nested structures
        elements = split_respecting_nesting(content)
        # Parse each element and convert to tuple
        elements |> Enum.map(&parse_term/1) |> List.to_tuple()

      # Add more cases as needed for other term types

      # Default case - try to convert to appropriate type
      true ->
        raise """
          Invalid type passed to Option:
          #{inspect(clean_string)}
        """
    end
  end

  # Helper to split a string by commas while respecting nested braces
  defp split_respecting_nesting(string) do
    split_with_nesting(string, [], "", 0)
  end

  defp split_with_nesting("", acc, current, _) do
    Enum.reverse([String.trim(current) | acc])
  end

  defp split_with_nesting("," <> rest, acc, current, 0) do
    split_with_nesting(rest, [String.trim(current) | acc], "", 0)
  end

  defp split_with_nesting("{" <> rest, acc, current, depth) do
    split_with_nesting(rest, acc, current <> "{", depth + 1)
  end

  defp split_with_nesting("}" <> rest, acc, current, depth) do
    split_with_nesting(rest, acc, current <> "}", depth - 1)
  end

  defp split_with_nesting(<<char::utf8, rest::binary>>, acc, current, depth) do
    split_with_nesting(rest, acc, current <> <<char::utf8>>, depth)
  end
end
