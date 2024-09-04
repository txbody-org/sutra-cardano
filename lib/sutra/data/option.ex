# credo:disable-for-this-file Credo.Check.Readability.FunctionNames
defmodule Sutra.Data.Option do
  @moduledoc """
    Common data types
  """

  defstruct [:option]

  @type t() :: %__MODULE__{option: atom() | module()}

  @spec sigil_OPTION(binary(), []) :: __MODULE__.t()
  def sigil_OPTION(":" <> v, []),
    do: %__MODULE__{option: String.to_existing_atom(v)}

  def sigil_OPTION(v, []),
    do: %__MODULE__{option: String.to_existing_atom("Elixir." <> v)}
end
