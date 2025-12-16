defmodule Sutra.Cardano.Blueprint.Common do
  @moduledoc """
  Common CIP-57 Blueprint schemas for standard Cardano types.

  This module provides predefined schemas for Cardano standard library types,
  allowing consistent encoding/decoding of data structures like OutputReference,
  Address, Credential, etc.

  ## Usage

  These schemas can be used with `Blueprint.encode/2` and `Blueprint.decode/2`:

      alias Sutra.Cardano.Blueprint
      alias Sutra.Cardano.Blueprint.Common

      # Encode an output reference
      oref = %{
        constructor: "OutputReference",
        fields: %{
          "transaction_id" => <<...>>,
          "output_index" => 0
        }
      }
      {:ok, encoded} = Blueprint.encode(oref, Common.output_reference())

      # Decode plutus data
      {:ok, decoded} = Blueprint.decode(plutus_data, Common.output_reference())

  ## Available Schemas

  The following standard Cardano types are available:

  - `bytes/0` - Raw bytes (ByteArray)
  - `integer/0` - Integer
  - `policy_id/0` - Policy ID (28 bytes)
  - `asset_name/0` - Asset name (bytes)
  - `transaction_id/0` - Transaction ID (32 bytes)
  - `output_reference/0` - Output Reference (tx_id, index)
  - `credential/0` - Credential (VerificationKey or Script)
  - `stake_credential/0` - Optional stake credential
  - `address/0` - Full Cardano address
  - `value/0` - Lovelace value (integer)
  - `datum/0` - Datum (none, hash, or inline)
  - `output/0` - Transaction output

  ## Integration with defdata/defenum

  These schemas can be referenced from modules using `defdata` and `defenum` macros
  by storing the schema as a module attribute and using `Blueprint.encode/2` in `to_plutus/1`.
  """

  # ============================================================================
  # Primitive Types
  # ============================================================================

  @doc "Schema for raw bytes (ByteArray)"
  def bytes do
    %{"dataType" => "bytes", "title" => "ByteArray"}
  end

  @doc "Schema for integer"
  def integer do
    %{"dataType" => "integer", "title" => "Int"}
  end

  # ============================================================================
  # Asset Types
  # ============================================================================

  @doc "Schema for Policy ID (28-byte hash)"
  def policy_id do
    %{"dataType" => "bytes", "title" => "PolicyId"}
  end

  @doc "Schema for Asset Name"
  def asset_name do
    %{"dataType" => "bytes", "title" => "AssetName"}
  end

  # ============================================================================
  # Transaction Types
  # ============================================================================

  @doc "Schema for Transaction ID (32-byte hash)"
  def transaction_id do
    %{"dataType" => "bytes", "title" => "TransactionId"}
  end

  @doc "Schema for Output Reference (transaction_id, output_index)"
  def output_reference do
    %{
      "title" => "OutputReference",
      "dataType" => "constructor",
      "index" => 0,
      "fields" => [
        %{"title" => "transaction_id", "dataType" => "bytes"},
        %{"title" => "output_index", "dataType" => "integer"}
      ]
    }
  end

  # ============================================================================
  # Credential Types
  # ============================================================================

  @doc "Schema for Credential (VerificationKey or Script)"
  def credential do
    %{
      "title" => "Credential",
      "anyOf" => [
        %{
          "title" => "VerificationKey",
          "dataType" => "constructor",
          "index" => 0,
          "fields" => [
            %{"title" => "hash", "dataType" => "bytes"}
          ]
        },
        %{
          "title" => "Script",
          "dataType" => "constructor",
          "index" => 1,
          "fields" => [
            %{"title" => "hash", "dataType" => "bytes"}
          ]
        }
      ]
    }
  end

  @doc "Schema for optional Stake Credential"
  def stake_credential do
    %{
      "title" => "Option$StakeCredential",
      "anyOf" => [
        %{
          "title" => "None",
          "dataType" => "constructor",
          "index" => 1,
          "fields" => []
        },
        %{
          "title" => "Some",
          "dataType" => "constructor",
          "index" => 0,
          "fields" => [
            %{
              "title" => "value",
              "anyOf" => [
                %{
                  "title" => "Inline",
                  "dataType" => "constructor",
                  "index" => 0,
                  "fields" => [credential()]
                },
                %{
                  "title" => "Pointer",
                  "dataType" => "constructor",
                  "index" => 1,
                  "fields" => [
                    %{"title" => "slot", "dataType" => "integer"},
                    %{"title" => "tx_index", "dataType" => "integer"},
                    %{"title" => "cert_index", "dataType" => "integer"}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  end

  # ============================================================================
  # Address Types
  # ============================================================================

  @doc "Schema for Cardano Address"
  def address do
    %{
      "title" => "Address",
      "dataType" => "constructor",
      "index" => 0,
      "fields" => [
        %{"title" => "payment_credential"} |> Map.merge(credential()),
        %{"title" => "stake_credential"} |> Map.merge(stake_credential())
      ]
    }
  end

  # ============================================================================
  # Value Types
  # ============================================================================

  @doc "Schema for Lovelace value (simple integer)"
  def lovelace do
    %{"dataType" => "integer", "title" => "Lovelace"}
  end

  @doc "Schema for asset quantity in a multi-asset value"
  def asset_quantity do
    %{
      "title" => "AssetQuantity",
      "dataType" => "list",
      "items" => [
        policy_id(),
        %{
          "dataType" => "map",
          "keys" => asset_name(),
          "values" => integer()
        }
      ]
    }
  end

  # ============================================================================
  # Datum Types
  # ============================================================================

  @doc "Schema for Datum (NoDatum, DatumHash, or InlineDatum)"
  def datum do
    %{
      "title" => "Datum",
      "anyOf" => [
        %{
          "title" => "NoDatum",
          "dataType" => "constructor",
          "index" => 0,
          "fields" => []
        },
        %{
          "title" => "DatumHash",
          "dataType" => "constructor",
          "index" => 1,
          "fields" => [
            %{"title" => "hash", "dataType" => "bytes"}
          ]
        },
        %{
          "title" => "InlineDatum",
          "dataType" => "constructor",
          "index" => 2,
          "fields" => [
            %{"title" => "Data", "description" => "Any Plutus data."}
          ]
        }
      ]
    }
  end

  # ============================================================================
  # Script Reference Types
  # ============================================================================

  @doc "Schema for optional Script Reference"
  def script_reference do
    %{
      "title" => "Option$ScriptRef",
      "anyOf" => [
        %{
          "title" => "None",
          "dataType" => "constructor",
          "index" => 1,
          "fields" => []
        },
        %{
          "title" => "Some",
          "dataType" => "constructor",
          "index" => 0,
          "fields" => [
            %{"title" => "script", "dataType" => "bytes"}
          ]
        }
      ]
    }
  end

  # ============================================================================
  # Output Types
  # ============================================================================

  @doc "Schema for Transaction Output"
  def output do
    %{
      "title" => "Output",
      "dataType" => "constructor",
      "index" => 0,
      "fields" => [
        Map.put(address(), "title", "address"),
        %{"title" => "value", "dataType" => "integer"},
        Map.put(datum(), "title", "datum"),
        Map.put(script_reference(), "title", "reference_script")
      ]
    }
  end

  # ============================================================================
  # Input Types
  # ============================================================================

  @doc "Schema for Transaction Input"
  def input do
    %{
      "title" => "Input",
      "dataType" => "constructor",
      "index" => 0,
      "fields" => [
        Map.put(output_reference(), "title", "output_reference"),
        Map.put(output(), "title", "output")
      ]
    }
  end

  # ============================================================================
  # Time Types
  # ============================================================================

  @doc "Schema for POSIX time (milliseconds since epoch)"
  def posix_time do
    %{"dataType" => "integer", "title" => "POSIXTime"}
  end

  # ============================================================================
  # Helper to get all available schemas
  # ============================================================================

  @doc "Returns a map of all available schema names to their schemas"
  def all do
    %{
      bytes: bytes(),
      integer: integer(),
      policy_id: policy_id(),
      asset_name: asset_name(),
      transaction_id: transaction_id(),
      output_reference: output_reference(),
      credential: credential(),
      stake_credential: stake_credential(),
      address: address(),
      lovelace: lovelace(),
      asset_quantity: asset_quantity(),
      datum: datum(),
      script_reference: script_reference(),
      output: output(),
      input: input(),
      posix_time: posix_time()
    }
  end

  @doc "Get a schema by name (atom)"
  def get(name) when is_atom(name) do
    Map.get(all(), name)
  end
end
