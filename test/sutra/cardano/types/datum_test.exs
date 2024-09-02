defmodule Sutra.Cardano.Types.DatumTest do
  use ExUnit.Case

  alias Sutra.Data
  alias Sutra.Cardano.Types.Datum

  describe "Datum Parsers" do
    @no_datum_cbor "D87980"
    @inline_datum_cbor "D87B9F459F010203FFFF"
    @datum_hash_cbor "D87A9F4F736F6D652D646174756D2D68617368FF"

    test "from_plutus/1" do
      assert %Datum{kind: :no_datum, value: nil} == Datum.from_plutus(@no_datum_cbor)

      assert %Datum{kind: :inline_datum, value: "\x9F\x01\x02\x03\xFF"} ==
               Datum.from_plutus(@inline_datum_cbor)

      assert %Datum{kind: :datum_hash, value: "some-datum-hash"} ==
               Datum.from_plutus(@datum_hash_cbor)
    end

    test "to_plutus/1" do
      assert Datum.to_plutus(%Datum{kind: :no_datum, value: nil}) |> Data.encode() ==
               @no_datum_cbor

      assert Datum.to_plutus(%Datum{kind: :inline_datum, value: "\x9F\x01\x02\x03\xFF"})
             |> Data.encode() ==
               @inline_datum_cbor

      assert Datum.to_plutus(%Datum{kind: :datum_hash, value: "some-datum-hash"}) |> Data.encode() ==
               @datum_hash_cbor
    end
  end
end
