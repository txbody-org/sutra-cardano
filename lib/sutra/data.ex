defmodule Sutra.Data do
  @moduledoc """
    Data Allow constructing Object, Enum and converting to and from Plutus Encodings

    For Example `OutputReference` from Aiken stdlib can be defined as follows:

    ```elixir
      defdata name: OutputReference do
        data :transaction_id, :string
        data :output_index, :integer
      end
    ```

    we can also override default encoding & decoding by passing
    `encode_with` & `decode_with` option as

    ```elixir
      defdata name: Input  do
        data :output_reference, OutputReference
        data :output, :output, encode_with: &custom_encode/1, decode_with: &custom_decode/1
      end
    ```

    ## Defining Enum

    New block-based syntax:

    ```elixir
      defenum name: Datum do
        field :no_datum, :null
        field :datum_hash, :string
        field :inline_datum, :string
      end
    ```

    With explicit indices:

    ```elixir
      defenum name: Datum do
        field :inline_datum, :string, index: 1
        field :datum_hash, :string, index: 0
        field :no_datum, :null, index: 2
      end
    ```


  """

  alias Sutra.Data.MacroHelper.EnumMacro
  alias Sutra.Data.MacroHelper.ObjectMacro
  alias Sutra.Data.Plutus.Constr

  defmacro __using__(_) do
    quote do
      import Sutra.Data, only: [defdata: 2, defdata: 1, defenum: 1, defenum: 2, data: 3, data: 2]
      import Sutra.Data.Option
    end
  end

  defmacro defdata(opts \\ [], do: block), do: ObjectMacro.__define_object__(opts, block)

  @spec data(atom(), atom(), Keyword.t()) :: Macro.t()
  defmacro data(name, type, opts \\ []), do: ObjectMacro.__setup_data__(name, type, opts)

  # New block-based defenum syntax
  defmacro defenum(opts, do: block), do: EnumMacro.__define__(opts, block)

  # Legacy keyword list defenum syntax
  defmacro defenum(opts), do: EnumMacro.__define__(opts)

  defdelegate encode(data), to: Sutra.Data.Plutus
  defdelegate decode(hex), to: Sutra.Data.Plutus
  defdelegate decode!(hex), to: Sutra.Data.Plutus

  def void, do: %Constr{index: 0, fields: []}
end
