defmodule Sutra.Cardano.Transaction.DatumTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Data

  describe "Datum Parsers" do
    @no_datum_cbor "D87980"
    @inline_datum_cbor "D87B9F459F010203FFFF"
    @datum_hash_cbor "D87A9F4F736F6D652D646174756D2D68617368FF"

    test "from_plutus/1" do
      assert {:ok, %Datum{kind: :no_datum, value: nil}} == Datum.from_plutus(@no_datum_cbor)

      assert {:ok, %Datum{kind: :inline_datum, value: "9f010203ff"}} ==
               Datum.from_plutus(@inline_datum_cbor)

      assert {:ok, %Datum{kind: :datum_hash, value: "736f6d652d646174756d2d68617368"}} ==
               Datum.from_plutus(@datum_hash_cbor)
    end

    test "to_plutus/1" do
      assert @no_datum_cbor ==
               Datum.to_plutus(%Datum{kind: :no_datum, value: nil})
               |> Data.encode()
               |> Base.encode16()

      assert @inline_datum_cbor ==
               Datum.to_plutus(%Datum{kind: :inline_datum, value: "\x9F\x01\x02\x03\xFF"})
               |> Data.encode()
               |> Base.encode16()

      assert @datum_hash_cbor ==
               Datum.to_plutus(%Datum{kind: :datum_hash, value: "some-datum-hash"})
               |> Data.encode()
               |> Base.encode16()
    end
  end
end
