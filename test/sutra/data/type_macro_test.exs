defmodule Sutra.Data.TypeMacroTest do
  use ExUnit.Case
  use Sutra.Data
  alias Sutra.Data.Cbor

  # Define a type alias for List<(Int, ByteArray)>
  deftype(name: RedeemerList, type: [{:integer, :bytes}])

  # Define a simple type alias for Integer
  deftype(name: MyInt, type: :integer)

  # Define type for List<List<ByteArray>>
  deftype(name: BytesListList, type: [[:text]])

  # Define type for (List<Int>, ByteArray)
  deftype(name: TupleListByteArray, type: {[:integer], :bytes})

  describe "deftype" do
    test "generates __schema__ function" do
      schema = RedeemerList.__schema__()
      assert schema["dataType"] == "list"
      # Tuple is represented as list in blueprint usually? Or specialized tuple schema?
      assert schema["items"]["dataType"] == "list"

      # SchemaBuilder.type_to_schema({:integer, :bytes}) creates a list with items [int, bytes] and title Tuple
    end

    test "to_plutus encodes matching data" do
      input = [{42, "deadbeef"}, {100, "cafebabe"}]

      encoded = RedeemerList.to_plutus(input)
      assert match?(%Sutra.Data.Plutus.PList{}, encoded)

      %Sutra.Data.Plutus.PList{value: items} = encoded
      assert length(items) == 2
      [first | _] = items
      assert match?(%Sutra.Data.Plutus.PList{}, first)
    end

    test "from_plutus decodes data" do
      input = [{42, "deadbeef"}, {100, "cafebabe"}]
      encoded = RedeemerList.to_plutus(input)

      {:ok, decoded} = RedeemerList.from_plutus(encoded)
      # Binary string "deadbeef" encoded as bytes is generally "deadbeef" (raw bytes)
      # But if we pass "deadbeef" to something expecting hex it might decode.
      # Blueprint `encode_bytes` attempts hex decode of "deadbeef" -> <<0xDE, 0xAD, 0xBE, 0xEF>>
      # Then `decode_bytes` encodes back to hex string -> "deadbeef"
      assert decoded == [{42, "deadbeef"}, {100, "cafebabe"}]
    end

    test "handles primitive types" do
      encoded = MyInt.to_plutus(123)
      assert encoded == 123
      {:ok, decoded} = MyInt.from_plutus(123)
      assert decoded == 123
    end

    test "user requested test case for List<(Int, ByteArray)>" do
      input = [{1, "a"}, {2, "b"}]

      encoded = RedeemerList.to_plutus(input)
      hex = Cbor.encode_hex(encoded)

      assert hex == "9F9F014161FF9F024162FFFF"
    end

    test "user requested test case for List<List<ByteArray>>" do
      input = [["aaa", "bbb", "ccc"], ["aa", "bb"], ["a", "b"], []]

      encoded = BytesListList.to_plutus(input)
      hex = Cbor.encode_hex(encoded)

      assert hex == "9F9F436161614362626243636363FF9F426161426262FF9F41614162FF80FF"
    end

    test "user requested test case for (List<Int>, ByteArray)" do
      # input: {[1, 2, 3], "deadbeef"}
      # output: 9F9F010203FF44DEADBEEFFF
      input = {[1, 2, 3], "deadbeef"}

      encoded = TupleListByteArray.to_plutus(input)
      hex = Cbor.encode_hex(encoded)

      assert hex == "9F9F010203FF44DEADBEEFFF"
    end

    test "decoding test for List<List<ByteArray>>" do
      hex = "9F9F436161614362626243636363FF9F426161426262FF9F41614162FF80FF"
      {:ok, plutus_data} = Sutra.Data.decode(hex)

      {:ok, decoded} = BytesListList.from_plutus(plutus_data)

      assert decoded == [["aaa", "bbb", "ccc"], ["aa", "bb"], ["a", "b"], []]
    end

    test "decoding test for (List<Int>, ByteArray)" do
      hex = "9F9F010203FF44DEADBEEFFF"
      {:ok, plutus_data} = Sutra.Data.decode(hex)

      {:ok, decoded} = TupleListByteArray.from_plutus(plutus_data)

      assert decoded == {[1, 2, 3], "deadbeef"}
    end
  end
end
