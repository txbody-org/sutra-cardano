defmodule Sutra.DataTest.SimpleTupleDataTest do
  @moduledoc """
    test converting data types with simple tuple

    Aiken Example
    ```gleam 
      type UserWallet {
        pub_key: ByteArray,
        asset: (PolicyId, AssetName, Int)
      }
    ```

  """
  use ExUnit.Case, async: true

  use Sutra.Data

  alias Sutra.Data.Cbor

  @expected_hex "D8799F44C55DB5749F42C13242C1331864FFFF"

  defdata do
    data(:pub_key, :string)
    data(:asset, {:string, :string, :integer})
  end

  test "to_plutus/1 converts data with tuple" do
    sample_data = %__MODULE__{pub_key: "C55DB574", asset: {"C132", "C133", 100}}

    assert to_plutus(sample_data) |> Cbor.encode_hex() == @expected_hex
  end

  test "from_plutus/1 converts plutus data to struct" do
    assert {:ok,
            %__MODULE__{
              pub_key: "C55DB574",
              asset: {"C132", "C133", 100}
            }} == from_plutus(@expected_hex)
  end
end
