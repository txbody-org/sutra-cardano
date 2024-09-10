defmodule Sutra.Data do
  @moduledoc """
    Data Manager for Plutus
  """

  alias Sutra.Data.MacroHelper.EnumMacro
  alias Sutra.Data.MacroHelper.ObjectMacro

  defmacro __using__(_) do
    quote do
      import Sutra.Data, only: [defdata: 2, defdata: 1, defenum: 1, data: 3, data: 2]
      import Sutra.Data.Option
    end
  end

  defmacro defdata(opts \\ [], do: block), do: ObjectMacro.__define_object__(opts, block)

  @spec data(atom(), atom(), Keyword.t()) :: Macro.t()
  defmacro data(name, type, opts \\ []), do: ObjectMacro.__setup_data__(name, type, opts)

  defmacro defenum(opts), do: EnumMacro.__define__(opts)
  defdelegate encode(data), to: Sutra.Data.Plutus
  defdelegate decode(hex), to: Sutra.Data.Plutus
  defdelegate decode!(hex), to: Sutra.Data.Plutus
end
