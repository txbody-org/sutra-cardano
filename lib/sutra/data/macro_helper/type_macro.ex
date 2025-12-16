defmodule Sutra.Data.MacroHelper.TypeMacro do
  @moduledoc """
  Macro Helper for Type Macros.

  Generates a module that acts as a type alias, implementing Blueprint schema compliance
  without defining a struct. Useful for wrapping primitive types, lists, or tuples
  that reuse encoding rules.
  """

  alias Sutra.Data.MacroHelper.SchemaBuilder

  def __define_type__(opts) do
    name = Keyword.fetch!(opts, :name)
    type_def = Keyword.fetch!(opts, :type)

    quote do
      defmodule unquote(name) do
        alias Sutra.Cardano.Blueprint

        @__blueprint_schema__ SchemaBuilder.type_to_schema(unquote(Macro.escape(type_def)))

        @doc "Returns the Blueprint schema for this type"
        def __schema__, do: @__blueprint_schema__

        @doc "Encode value to Plutus data"
        def to_plutus(value) do
          case Blueprint.encode(value, @__blueprint_schema__) do
            {:ok, encoded} -> encoded
            {:error, reason} -> raise "Encoding failed: #{inspect(reason)}"
          end
        end

        @doc "Decode from Plutus data"
        def from_plutus(plutus_data) do
           case Blueprint.decode(plutus_data, @__blueprint_schema__) do
             {:ok, decoded} -> {:ok, decoded}
             error -> error
           end
        end
      end
    end
  end
end
