defmodule Sutra.Cardano.BlueprintTest do
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Blueprint
  alias Sutra.Data.Plutus.{Constr, PList}

  describe "encode/3 - primitive types" do
    test "encodes integer" do
      schema = %{"dataType" => "integer"}
      assert {:ok, 42} = Blueprint.encode(42, schema)
      assert {:ok, 0} = Blueprint.encode(0, schema)
      assert {:ok, -100} = Blueprint.encode(-100, schema)
    end

    test "encodes bytes from hex string" do
      schema = %{"dataType" => "bytes"}

      assert {:ok, %CBOR.Tag{tag: :bytes, value: <<222, 173, 190, 239>>}} =
               Blueprint.encode("deadbeef", schema)
    end

    test "encodes raw binary bytes" do
      schema = %{"dataType" => "bytes"}
      # Non-hex binary should pass through as-is
      assert {:ok, %CBOR.Tag{tag: :bytes, value: "hello"}} = Blueprint.encode("hello", schema)
    end

    test "passes through CBOR.Tag bytes" do
      schema = %{"dataType" => "bytes"}
      tag = %CBOR.Tag{tag: :bytes, value: <<1, 2, 3>>}
      assert {:ok, ^tag} = Blueprint.encode(tag, schema)
    end

    test "returns error for invalid integer" do
      schema = %{"dataType" => "integer"}
      assert {:error, {:encode_error, _}} = Blueprint.encode("not an int", schema)
    end

    test "returns error for invalid bytes" do
      schema = %{"dataType" => "bytes"}
      assert {:error, {:encode_error, _}} = Blueprint.encode(123, schema)
    end
  end

  describe "encode/3 - lists" do
    test "encodes list of integers" do
      schema = %{"dataType" => "list", "items" => %{"dataType" => "integer"}}
      assert {:ok, %PList{value: [1, 2, 3]}} = Blueprint.encode([1, 2, 3], schema)
    end

    test "encodes empty list" do
      schema = %{"dataType" => "list", "items" => %{"dataType" => "integer"}}
      assert {:ok, %PList{value: []}} = Blueprint.encode([], schema)
    end

    test "encodes list of bytes" do
      schema = %{"dataType" => "list", "items" => %{"dataType" => "bytes"}}
      {:ok, result} = Blueprint.encode(["abcd", "1234"], schema)
      assert %PList{value: [%CBOR.Tag{tag: :bytes}, %CBOR.Tag{tag: :bytes}]} = result
    end
  end

  describe "encode/3 - tuples" do
    test "encodes tuple from list" do
      schema = %{
        "dataType" => "list",
        "items" => [
          %{"dataType" => "bytes"},
          %{"dataType" => "integer"}
        ]
      }

      assert {:ok, %PList{value: [%CBOR.Tag{tag: :bytes}, 42]}} =
               Blueprint.encode(["abcd", 42], schema)
    end

    test "encodes tuple from actual tuple" do
      schema = %{
        "dataType" => "list",
        "items" => [
          %{"dataType" => "integer"},
          %{"dataType" => "integer"}
        ]
      }

      assert {:ok, %PList{value: [1, 2]}} = Blueprint.encode({1, 2}, schema)
    end

    test "returns error for tuple size mismatch" do
      schema = %{
        "dataType" => "list",
        "items" => [
          %{"dataType" => "integer"},
          %{"dataType" => "integer"}
        ]
      }

      assert {:error, {:encode_error, _}} = Blueprint.encode([1], schema)
    end
  end

  describe "encode/3 - constructors" do
    test "encodes unit constructor by name" do
      schema = %{
        "anyOf" => [
          %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => []},
          %{"title" => "Bar", "dataType" => "constructor", "index" => 1, "fields" => []}
        ]
      }

      assert {:ok, %Constr{index: 0, fields: []}} = Blueprint.encode(:Foo, schema)
      assert {:ok, %Constr{index: 1, fields: []}} = Blueprint.encode("Bar", schema)
    end

    test "encodes constructor with map-style value" do
      schema = %{
        "anyOf" => [
          %{"title" => "CreateLend", "dataType" => "constructor", "index" => 0, "fields" => []}
        ]
      }

      assert {:ok, %Constr{index: 0, fields: []}} =
               Blueprint.encode(%{constructor: "CreateLend"}, schema)
    end

    test "encodes constructor with named fields" do
      schema = %{
        "anyOf" => [
          %{
            "title" => "ApplyLoan",
            "dataType" => "constructor",
            "index" => 0,
            "fields" => [
              %{"title" => "timestamp", "dataType" => "integer"}
            ]
          }
        ]
      }

      value = %{constructor: "ApplyLoan", fields: %{"timestamp" => 12_345}}
      assert {:ok, %Constr{index: 0, fields: [12_345]}} = Blueprint.encode(value, schema)
    end

    test "encodes constructor with positional fields" do
      schema = %{
        "anyOf" => [
          %{
            "title" => "ApplyLoan",
            "dataType" => "constructor",
            "index" => 0,
            "fields" => [
              %{"title" => "timestamp", "dataType" => "integer"}
            ]
          }
        ]
      }

      value = {:constr, 0, [12_345]}
      assert {:ok, %Constr{index: 0, fields: [12_345]}} = Blueprint.encode(value, schema)
    end

    test "returns error for unknown constructor" do
      schema = %{
        "anyOf" => [
          %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => []}
        ]
      }

      assert {:error, {:encode_error, _}} = Blueprint.encode(:Unknown, schema)
    end
  end

  describe "encode/3 - references" do
    test "resolves simple ref" do
      definitions = %{
        "Int" => %{"dataType" => "integer"}
      }

      schema = %{"$ref" => "#/definitions/Int"}
      assert {:ok, 42} = Blueprint.encode(42, schema, definitions)
    end

    test "resolves URL-encoded ref" do
      definitions = %{
        "cardano/assets/PolicyId" => %{"dataType" => "bytes"}
      }

      schema = %{"$ref" => "#/definitions/cardano~1assets~1PolicyId"}

      assert {:ok, %CBOR.Tag{tag: :bytes}} = Blueprint.encode("abcd", schema, definitions)
    end

    test "returns error for missing definition" do
      schema = %{"$ref" => "#/definitions/NotFound"}
      assert {:error, {:encode_error, _}} = Blueprint.encode(42, schema, %{})
    end
  end

  describe "decode/3 - primitive types" do
    test "decodes integer" do
      schema = %{"dataType" => "integer"}
      assert {:ok, 42} = Blueprint.decode(42, schema)
    end

    test "decodes bytes from CBOR.Tag as hex string" do
      schema = %{"dataType" => "bytes"}
      tag = %CBOR.Tag{tag: :bytes, value: <<1, 2, 3>>}
      assert {:ok, "010203"} = Blueprint.decode(tag, schema)
    end

    test "decodes raw binary bytes as hex string" do
      schema = %{"dataType" => "bytes"}
      assert {:ok, "68656c6c6f"} = Blueprint.decode("hello", schema)
    end
  end

  describe "decode/3 - lists" do
    test "decodes PList of integers" do
      schema = %{"dataType" => "list", "items" => %{"dataType" => "integer"}}
      plist = %PList{value: [1, 2, 3]}
      assert {:ok, [1, 2, 3]} = Blueprint.decode(plist, schema)
    end

    test "decodes raw list of integers" do
      schema = %{"dataType" => "list", "items" => %{"dataType" => "integer"}}
      assert {:ok, [1, 2, 3]} = Blueprint.decode([1, 2, 3], schema)
    end
  end

  describe "decode/3 - tuples" do
    test "decodes tuple from PList as Elixir tuple" do
      schema = %{
        "dataType" => "list",
        "items" => [
          %{"dataType" => "integer"},
          %{"dataType" => "bytes"}
        ]
      }

      plist = %PList{value: [42, "hello"]}
      # Returns tuple, bytes as hex
      assert {:ok, {42, "68656c6c6f"}} = Blueprint.decode(plist, schema)
    end
  end

  describe "decode/3 - constructors" do
    test "decodes unit constructor" do
      schema = %{
        "anyOf" => [
          %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => []},
          %{"title" => "Bar", "dataType" => "constructor", "index" => 1, "fields" => []}
        ]
      }

      assert {:ok, %{constructor: "Foo", fields: %{}}} =
               Blueprint.decode(%Constr{index: 0, fields: []}, schema)

      assert {:ok, %{constructor: "Bar", fields: %{}}} =
               Blueprint.decode(%Constr{index: 1, fields: []}, schema)
    end

    test "decodes constructor with fields" do
      schema = %{
        "anyOf" => [
          %{
            "title" => "ApplyLoan",
            "dataType" => "constructor",
            "index" => 0,
            "fields" => [
              %{"title" => "timestamp", "dataType" => "integer"}
            ]
          }
        ]
      }

      constr = %Constr{index: 0, fields: [12_345]}

      assert {:ok, %{constructor: "ApplyLoan", fields: %{"timestamp" => 12_345}}} =
               Blueprint.decode(constr, schema)
    end

    test "returns error for unknown constructor index" do
      schema = %{
        "anyOf" => [
          %{"title" => "Foo", "dataType" => "constructor", "index" => 0, "fields" => []}
        ]
      }

      assert {:error, {:decode_error, _}} =
               Blueprint.decode(%Constr{index: 99, fields: []}, schema)
    end
  end

  describe "roundtrip encoding/decoding" do
    test "roundtrips integer" do
      schema = %{"dataType" => "integer"}
      value = 42

      assert {:ok, encoded} = Blueprint.encode(value, schema)
      assert {:ok, ^value} = Blueprint.decode(encoded, schema)
    end

    test "roundtrips unit constructor" do
      schema = %{
        "anyOf" => [
          %{"title" => "CreateLend", "dataType" => "constructor", "index" => 2, "fields" => []}
        ]
      }

      value = %{constructor: "CreateLend", fields: %{}}

      assert {:ok, encoded} = Blueprint.encode(value, schema)
      assert {:ok, ^value} = Blueprint.decode(encoded, schema)
    end

    test "roundtrips constructor with fields" do
      schema = %{
        "anyOf" => [
          %{
            "title" => "OutputReference",
            "dataType" => "constructor",
            "index" => 0,
            "fields" => [
              %{"title" => "transaction_id", "dataType" => "bytes"},
              %{"title" => "output_index", "dataType" => "integer"}
            ]
          }
        ]
      }

      value = %{
        constructor: "OutputReference",
        fields: %{
          "transaction_id" => "abcd1234",
          "output_index" => 0
        }
      }

      assert {:ok, encoded} = Blueprint.encode(value, schema)
      assert {:ok, decoded} = Blueprint.decode(encoded, schema)

      assert decoded.constructor == "OutputReference"
      assert decoded.fields["output_index"] == 0
      # Bytes are decoded as raw binary
      assert is_binary(decoded.fields["transaction_id"])
    end

    test "roundtrips nested structure with refs" do
      definitions = %{
        "Int" => %{"dataType" => "integer"},
        "POSIXTime" => %{"dataType" => "integer"},
        "LoanMintRedeemer" => %{
          "anyOf" => [
            %{
              "title" => "ApplyLoan",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"$ref" => "#/definitions/POSIXTime"}
              ]
            },
            %{
              "title" => "PayBackLoan",
              "dataType" => "constructor",
              "index" => 2,
              "fields" => []
            }
          ]
        }
      }

      schema = %{"$ref" => "#/definitions/LoanMintRedeemer"}

      # Test PayBackLoan (no fields)
      value1 = %{constructor: "PayBackLoan", fields: %{}}
      assert {:ok, encoded1} = Blueprint.encode(value1, schema, definitions)
      assert {:ok, ^value1} = Blueprint.decode(encoded1, schema, definitions)

      # Test ApplyLoan (with field)
      value2 = {:constr, 0, [1_702_500_000_000]}
      assert {:ok, encoded2} = Blueprint.encode(value2, schema, definitions)
      assert {:ok, decoded2} = Blueprint.decode(encoded2, schema, definitions)
      assert decoded2.constructor == "ApplyLoan"
    end
  end
end
