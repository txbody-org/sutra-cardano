defmodule Sutra.DataTest.TupleInEnumTest do
  @moduledoc """
    test converting tuple data  inside enum

    Aiken Example

    ```gleam
      type UserRole{
        Admin(ByteArray, Int)
        Normal(ByteArray, ByteArray, ByteArray)
      }   
    
    ```
  """
  alias Sutra.Data.Cbor
  use ExUnit.Case, async: true

  use Sutra.Data

  defenum(
    admin: {:string, :integer},
    normal: {:string, :string, :string}
  )

  @expected_admin_hex "D8799F42C1231832FF"
  @expected_normal_hex "D87A9F42C12342C12242C121FF"

  test "to_plutus/1 converts enum with tuple kind" do
    admin = %__MODULE__{kind: :admin, value: {"c123", 50}}
    normal = %__MODULE__{kind: :normal, value: {"c123", "c122", "c121"}}

    assert to_plutus(normal) |> Cbor.encode_hex() == @expected_normal_hex
    assert to_plutus(admin) |> Cbor.encode_hex() == @expected_admin_hex
  end

  test "from_plutus/1 converts hex to enum" do
    admin = %__MODULE__{kind: :admin, value: {"c123", 50}}
    normal = %__MODULE__{kind: :normal, value: {"c123", "c122", "c121"}}

    assert {:ok, admin} == from_plutus(@expected_admin_hex)
    assert {:ok, normal} == from_plutus(@expected_normal_hex)
  end
end
