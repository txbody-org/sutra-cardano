defmodule Sutra.Cardano.Blueprint.ParserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Blueprint
  alias Sutra.Cardano.Blueprint.Parser
  alias Sutra.Data.Plutus.Constr

  describe "resolve_schema/2" do
    test "resolves simple ref" do
      definitions = %{
        "Int" => %{"dataType" => "integer"}
      }

      schema = %{"$ref" => "#/definitions/Int"}
      assert {:ok, %{"dataType" => "integer"}} = Parser.resolve_schema(schema, definitions)
    end

    test "resolves URL-encoded ref path" do
      definitions = %{
        "cardano/assets/PolicyId" => %{"dataType" => "bytes", "title" => "PolicyId"}
      }

      schema = %{"$ref" => "#/definitions/cardano~1assets~1PolicyId"}

      assert {:ok, %{"dataType" => "bytes", "title" => "PolicyId"}} =
               Parser.resolve_schema(schema, definitions)
    end

    test "resolves nested refs in constructor fields" do
      definitions = %{
        "Int" => %{"dataType" => "integer"},
        "MyConstructor" => %{
          "anyOf" => [
            %{
              "title" => "Foo",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"title" => "value", "$ref" => "#/definitions/Int"}
              ]
            }
          ]
        }
      }

      schema = %{"$ref" => "#/definitions/MyConstructor"}
      {:ok, resolved} = Parser.resolve_schema(schema, definitions)

      assert %{"anyOf" => [variant]} = resolved
      assert variant["title"] == "Foo"
      assert [field] = variant["fields"]
      assert field["dataType"] == "integer"
      assert field["title"] == "value"
    end

    test "resolves deeply nested refs" do
      definitions = %{
        "ByteArray" => %{"dataType" => "bytes"},
        "Int" => %{"dataType" => "integer"},
        "OutputReference" => %{
          "anyOf" => [
            %{
              "title" => "OutputReference",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"title" => "transaction_id", "$ref" => "#/definitions/ByteArray"},
                %{"title" => "output_index", "$ref" => "#/definitions/Int"}
              ]
            }
          ]
        },
        "Option$OutputReference" => %{
          "anyOf" => [
            %{
              "title" => "Some",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"$ref" => "#/definitions/OutputReference"}
              ]
            },
            %{
              "title" => "None",
              "dataType" => "constructor",
              "index" => 1,
              "fields" => []
            }
          ]
        }
      }

      schema = %{"$ref" => "#/definitions/Option$OutputReference"}
      {:ok, resolved} = Parser.resolve_schema(schema, definitions)

      # Check None variant
      none_variant = Enum.find(resolved["anyOf"], &(&1["title"] == "None"))
      assert none_variant["fields"] == []

      # Check Some variant - should have fully resolved OutputReference
      some_variant = Enum.find(resolved["anyOf"], &(&1["title"] == "Some"))
      [inner] = some_variant["fields"]
      assert %{"anyOf" => [output_ref]} = inner
      assert output_ref["title"] == "OutputReference"
      assert length(output_ref["fields"]) == 2

      [tx_id_field, output_idx_field] = output_ref["fields"]
      assert tx_id_field["dataType"] == "bytes"
      assert output_idx_field["dataType"] == "integer"
    end

    test "resolves list item refs" do
      definitions = %{
        "ByteArray" => %{"dataType" => "bytes"}
      }

      schema = %{
        "dataType" => "list",
        "items" => %{"$ref" => "#/definitions/ByteArray"}
      }

      {:ok, resolved} = Parser.resolve_schema(schema, definitions)
      assert resolved["dataType"] == "list"
      assert resolved["items"]["dataType"] == "bytes"
    end

    test "resolves tuple item refs" do
      definitions = %{
        "ByteArray" => %{"dataType" => "bytes"},
        "Int" => %{"dataType" => "integer"}
      }

      schema = %{
        "dataType" => "list",
        "items" => [
          %{"$ref" => "#/definitions/ByteArray"},
          %{"$ref" => "#/definitions/Int"}
        ]
      }

      {:ok, resolved} = Parser.resolve_schema(schema, definitions)
      assert resolved["dataType"] == "list"
      assert [first, second] = resolved["items"]
      assert first["dataType"] == "bytes"
      assert second["dataType"] == "integer"
    end

    test "returns error for missing definition" do
      schema = %{"$ref" => "#/definitions/NotFound"}
      assert {:error, {:definition_not_found, "NotFound"}} = Parser.resolve_schema(schema, %{})
    end

    test "handles recursive types without infinite loop" do
      # A type that references itself (like a linked list)
      definitions = %{
        "LinkedList" => %{
          "anyOf" => [
            %{
              "title" => "Cons",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"title" => "head", "dataType" => "integer"},
                %{"title" => "tail", "$ref" => "#/definitions/LinkedList"}
              ]
            },
            %{
              "title" => "Nil",
              "dataType" => "constructor",
              "index" => 1,
              "fields" => []
            }
          ]
        }
      }

      schema = %{"$ref" => "#/definitions/LinkedList"}
      # Should not hang or crash
      {:ok, resolved} = Parser.resolve_schema(schema, definitions)

      # The first level should be resolved, recursive ref should be preserved
      assert %{"anyOf" => variants} = resolved
      assert length(variants) == 2
    end

    test "preserves primitive schemas as-is" do
      schema = %{"dataType" => "integer"}
      {:ok, resolved} = Parser.resolve_schema(schema, %{})
      assert resolved == schema
    end
  end

  describe "parse_validators/1" do
    test "parses validators from blueprint" do
      blueprint = %{
        "validators" => [
          %{
            "title" => "test.validator.spend",
            "datum" => %{
              "schema" => %{"$ref" => "#/definitions/Int"}
            },
            "redeemer" => %{
              "schema" => %{"$ref" => "#/definitions/MyRedeemer"}
            },
            "parameters" => [
              %{
                "title" => "param1",
                "schema" => %{"$ref" => "#/definitions/ByteArray"}
              }
            ],
            "compiledCode" => "deadbeef",
            "hash" => "abc123"
          }
        ],
        "definitions" => %{
          "Int" => %{"dataType" => "integer"},
          "ByteArray" => %{"dataType" => "bytes"},
          "MyRedeemer" => %{
            "anyOf" => [
              %{"title" => "Action", "dataType" => "constructor", "index" => 0, "fields" => []}
            ]
          }
        }
      }

      {:ok, validators} = Parser.parse_validators(blueprint)
      assert length(validators) == 1

      [v] = validators
      assert v.title == "test.validator.spend"
      assert v.datum_schema["dataType"] == "integer"
      assert %{"anyOf" => [_]} = v.redeemer_schema
      assert v.compiled_code == "deadbeef"
      assert v.hash == "abc123"
      assert [param] = v.parameters
      assert param["schema"]["dataType"] == "bytes"
    end

    test "handles validators without datum" do
      blueprint = %{
        "validators" => [
          %{
            "title" => "test.validator.mint",
            "redeemer" => %{
              "schema" => %{"dataType" => "integer"}
            }
          }
        ],
        "definitions" => %{}
      }

      {:ok, [v]} = Parser.parse_validators(blueprint)
      assert v.datum_schema == nil
      assert v.redeemer_schema["dataType"] == "integer"
    end

    test "returns error for invalid blueprint" do
      assert {:error, :invalid_blueprint_format} = Parser.parse_validators(%{})
    end
  end

  describe "integration with Blueprint encode/decode" do
    test "resolved schema works without passing definitions" do
      definitions = %{
        "POSIXTime" => %{"dataType" => "integer"},
        "LoanMintRedeemer" => %{
          "anyOf" => [
            %{
              "title" => "ApplyLoan",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"title" => "timestamp", "$ref" => "#/definitions/POSIXTime"}
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

      # Resolve the schema
      {:ok, resolved} = Parser.resolve_schema(schema, definitions)

      # Now encode/decode WITHOUT passing definitions
      value = %{constructor: "PayBackLoan", fields: %{}}
      {:ok, encoded} = Blueprint.encode(value, resolved)
      {:ok, decoded} = Blueprint.decode(encoded, resolved)
      assert decoded == value

      # With fields
      value2 = %{constructor: "ApplyLoan", fields: %{"timestamp" => 1_702_500_000_000}}
      {:ok, encoded2} = Blueprint.encode(value2, resolved)
      {:ok, decoded2} = Blueprint.decode(encoded2, resolved)
      assert decoded2.constructor == "ApplyLoan"
      assert decoded2.fields["timestamp"] == 1_702_500_000_000
    end

    test "works with complex nested types from real blueprint" do
      definitions = %{
        "ByteArray" => %{"dataType" => "bytes"},
        "Int" => %{"dataType" => "integer"},
        "cardano/assets/PolicyId" => %{"dataType" => "bytes", "title" => "PolicyId"},
        "cardano/assets/AssetName" => %{"dataType" => "bytes", "title" => "AssetName"},
        "StakeDatum" => %{
          "anyOf" => [
            %{
              "title" => "StakeDatum",
              "dataType" => "constructor",
              "index" => 0,
              "fields" => [
                %{"title" => "stake_amt", "$ref" => "#/definitions/Int"},
                %{
                  "title" => "stake_base_policy_id",
                  "$ref" => "#/definitions/cardano~1assets~1PolicyId"
                },
                %{
                  "title" => "stake_base_asset_name",
                  "$ref" => "#/definitions/cardano~1assets~1AssetName"
                }
              ]
            }
          ]
        }
      }

      schema = %{"$ref" => "#/definitions/StakeDatum"}
      {:ok, resolved} = Parser.resolve_schema(schema, definitions)

      # Verify the resolved schema structure
      [variant] = resolved["anyOf"]
      assert variant["title"] == "StakeDatum"
      assert length(variant["fields"]) == 3

      [f1, f2, f3] = variant["fields"]
      assert f1["title"] == "stake_amt"
      assert f1["dataType"] == "integer"
      assert f2["title"] == "stake_base_policy_id"
      assert f2["dataType"] == "bytes"
      assert f3["title"] == "stake_base_asset_name"
      assert f3["dataType"] == "bytes"

      # Encode and decode
      value = %{
        constructor: "StakeDatum",
        fields: %{
          "stake_amt" => 1000,
          "stake_base_policy_id" => "abcd1234",
          "stake_base_asset_name" => "TOKEN"
        }
      }

      {:ok, encoded} = Blueprint.encode(value, resolved)
      assert %Constr{index: 0, fields: [1000, _, _]} = encoded

      {:ok, decoded} = Blueprint.decode(encoded, resolved)
      assert decoded.constructor == "StakeDatum"
      assert decoded.fields["stake_amt"] == 1000
    end
  end
end
