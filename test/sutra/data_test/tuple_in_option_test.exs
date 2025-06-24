defmodule Sutra.DataTest.TupleInOptionTest do
  @moduledoc """
    Test convertion Tuple In optional data

    Aiken Example

    ```gleam
      type option = Option<(ByteArray, ByteArray, Int)>
      let v = Some(#"c123", #"c122", 100)
    ```
  """

  use Sutra.Data

  use ExUnit.Case, async: true

  alias Sutra.Data.Cbor

  defdata do
    data(:optional, ~OPTION({:string, :string, :integer}))
  end

  @expected_hex "D8799FD8799F9F42C12342C1221864FFFFFF"

  test "to_plutus/1 converts optional data with tuple type" do
    opt = %__MODULE__{optional: {"c123", "c122", 100}}

    assert to_plutus(opt) |> Cbor.encode_hex() == @expected_hex
  end

  test "from_plutus/1 converts optional data with tuple" do
    opt = %__MODULE__{optional: {"c123", "c122", 100}}
    assert {:ok, opt} == from_plutus(@expected_hex)
  end
end
