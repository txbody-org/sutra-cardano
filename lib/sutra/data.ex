defmodule Sutra.Data do
  @moduledoc """
    Data Allow constructing Object, Enum and converting to and from Plutus Encodings

    For Example `OutputReference` from Aiken stdlib can be defined as follows:

    ```elixir
      defdata module: OutputReference do
        data :transaction_id, :string
        data :output_index, :integer
      end
    ```

    we can also override default encoding & decoding by passing
    `encode_with` & `decode_with` option as

    ```elixir
      defdata module: Input  do
        data :output_reference, OutputReference
        data :output, :output, encode_with: &custom_encode/1, decode_with: &custom_decode/1
      end
    ```

    ## Defining Enum

    ```elixir
      defmodule Datum do
        use Sutra.Data


        defenum(
          no_datum: :null,
          datum_hash: :string,
          inline_datum: :string
        )
      end
    ```
  """

  alias Sutra.Data.MacroHelper.EnumMacro
  alias Sutra.Data.MacroHelper.ObjectMacro
  alias Sutra.Data.Plutus.Constr

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

  def void, do: %Constr{index: 0, fields: []}
end
