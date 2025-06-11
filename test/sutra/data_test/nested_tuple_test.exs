defmodule Sutra.DataTest.NestedTupleTest do
  @moduledoc """
    Test Converting  Nested Tuple

    Aiken Example
    ```gleam
      type NestedTuple {
        options: Option<((ByteArray, ByteArray), (Int, Int))>,
        simple: ((Int, ByteArray), (ByteArray, Int)),
      } 

      let nested =
        NestedTuple {
          options: Some(((#"aaaa", #"bbbb"), (1, 2))),
          simple: ((0, #"0000"), (#"1111", 1)),
        }
    ```
  """
  use ExUnit.Case, async: true
  use Sutra.Data

  alias Sutra.Data.Cbor

  defdata name: NestedTuple do
    data(:options, ~OPTION({{:string, :string}, {:integer, :integer}}))
    data(:simple, {{:integer, :string}, {:string, :integer}})
  end

  @expected_hex "D8799FD8799F9F9F42AAAA42BBBBFF9F0102FFFFFF9F9F00420000FF9F42111101FFFFFF"

  test "to_plutus/1 converts nested tuple" do
    nested = %__MODULE__.NestedTuple{
      options: {{"AAAA", "BBBB"}, {1, 2}},
      simple: {{0, "0000"}, {"1111", 1}}
    }

    assert NestedTuple.to_plutus(nested) |> Cbor.encode_hex() == @expected_hex
  end

  test "from_plutus/1 converts nested tuple" do
    nested = %__MODULE__.NestedTuple{
      options: {{"AAAA", "BBBB"}, {1, 2}},
      simple: {{0, "0000"}, {"1111", 1}}
    }

    assert {:ok, nested} == NestedTuple.from_plutus(@expected_hex)
  end
end
