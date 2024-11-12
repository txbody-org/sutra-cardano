defmodule Sutra.Cardano.Transaction.OutputTest do
  @moduledoc false

  use ExUnit.Case

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Data

  describe "Output Plutus Encodings" do
    @output_cbor %{
      "no-datum-no-ref-script" =>
        "D8799FD8799FD8799F48736F6D652D6B6579FFD87A80FFA140A1401A000F4240D87980D87A80FF",
      "datum-hash-no-ref-script" =>
        "D8799FD8799FD8799F48736F6D652D6B6579FFD87A80FFA140A1401A000F4240D87A9F49736F6D652D68617368FFD87A80FF",
      "inline-datum-no-ref-script" =>
        "D8799FD8799FD8799F48736F6D652D6B6579FFD87A80FFA140A1401A000F4240D87B9F45D8799F01FFFFD87A80FF",
      "inline-datum-with-ref-script" =>
        "D8799FD8799FD8799F48736F6D652D6B6579FFD87A80FFA140A1401A000F4240D87B9F45D8799F01FFFFD8799F4F736F6D652D7265662D736372697074FFFF"
    }
    test "from_plutus/1 constructs datum from cbor" do
      assert {:ok,
              %Output{
                address: %Address{
                  address_type: :shelley,
                  network: nil,
                  payment_credential: %Address.Credential{
                    credential_type: :vkey,
                    hash: "some-key"
                  },
                  stake_credential: nil
                },
                datum: %Datum{kind: :no_datum, value: nil},
                reference_script: nil,
                value: %{
                  "lovelace" => 1_000_000
                }
              }} = Output.from_plutus(@output_cbor["no-datum-no-ref-script"])

      assert {:ok,
              %Output{
                address: %Address{
                  address_type: :shelley,
                  network: nil,
                  payment_credential: %Address.Credential{
                    credential_type: :vkey,
                    hash: "some-key"
                  },
                  stake_credential: nil
                },
                datum: %Datum{kind: :datum_hash, value: "736F6D652D68617368"},
                reference_script: nil,
                value: %{
                  "lovelace" => 1_000_000
                }
              }} = Output.from_plutus(@output_cbor["datum-hash-no-ref-script"])

      assert {:ok,
              %Output{
                address: %Address{
                  address_type: :shelley,
                  network: nil,
                  payment_credential: %Address.Credential{
                    credential_type: :vkey,
                    hash: "some-key"
                  },
                  stake_credential: nil
                },
                datum: %Datum{kind: :inline_datum, value: "D8799F01FF"},
                reference_script: nil,
                value: %{
                  "lovelace" => 1_000_000
                }
              }} = Output.from_plutus(@output_cbor["inline-datum-no-ref-script"])

      assert {:ok,
              %Output{
                address: %Address{
                  address_type: :shelley,
                  network: nil,
                  payment_credential: %Address.Credential{
                    credential_type: :vkey,
                    hash: "some-key"
                  },
                  stake_credential: nil
                },
                datum: %Datum{kind: :inline_datum, value: "D8799F01FF"},
                reference_script: "736F6D652D7265662D736372697074",
                value: %{
                  "lovelace" => 1_000_000
                }
              }} = Output.from_plutus(@output_cbor["inline-datum-with-ref-script"])
    end

    test "to_plutus/1 encodes output to plutus data" do
      assert @output_cbor["no-datum-no-ref-script"] ==
               Output.to_plutus(%Output{
                 address: %Address{
                   address_type: :shelley,
                   network: nil,
                   payment_credential: %Address.Credential{
                     credential_type: :vkey,
                     hash: "some-key"
                   },
                   stake_credential: nil
                 },
                 datum: %Datum{kind: :no_datum, value: nil},
                 reference_script: nil,
                 value: %{
                   "lovelace" => 1_000_000
                 }
               })
               |> Data.encode()

      assert @output_cbor["datum-hash-no-ref-script"] ==
               Output.to_plutus(%Output{
                 address: %Address{
                   address_type: :shelley,
                   network: nil,
                   payment_credential: %Address.Credential{
                     credential_type: :vkey,
                     hash: "some-key"
                   },
                   stake_credential: nil
                 },
                 datum: %Datum{kind: :datum_hash, value: "some-hash"},
                 reference_script: nil,
                 value: %{
                   "lovelace" => 1_000_000
                 }
               })
               |> Data.encode()

      assert @output_cbor["inline-datum-no-ref-script"] ==
               Output.to_plutus(%Output{
                 address: %Address{
                   address_type: :shelley,
                   network: nil,
                   payment_credential: %Address.Credential{
                     credential_type: :vkey,
                     hash: "some-key"
                   },
                   stake_credential: nil
                 },
                 datum: %Datum{kind: :inline_datum, value: <<216, 121, 159, 1, 255>>},
                 reference_script: nil,
                 value: %{
                   "lovelace" => 1_000_000
                 }
               })
               |> Data.encode()
    end
  end
end
