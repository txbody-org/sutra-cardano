defmodule Sutra.Cardano.Transaction.InputTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.OutputReference

  describe "Sort Inputs" do
    test "inputs are sorted correctly for same Transaction Ids" do
      input1 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "tx1",
            output_index: 11
          }
        }

      input2 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "tx1",
            output_index: 8
          }
        }

      input3 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "tx1",
            output_index: 21
          }
        }

      assert Input.sort_inputs([input1, input2, input3]) == [input2, input1, input3]
    end

    test "inputs are sorted correctly for different Transaction Ids" do
      input1 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "btx1",
            output_index: 11
          }
        }

      input2 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "atx1",
            output_index: 8
          }
        }

      input3 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "ctx1",
            output_index: 21
          }
        }

      assert Input.sort_inputs([input1, input2, input3]) == [input2, input1, input3]
    end

    test "inputs are sorted correctly for mixed txRefs" do
      input1 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "btx1",
            output_index: 11
          }
        }

      input2 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "atx1",
            output_index: 8
          }
        }

      input3 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "atx1",
            output_index: 21
          }
        }

      input4 =
        %Input{
          output_reference: %OutputReference{
            transaction_id: "btx1",
            output_index: 10
          }
        }

      assert Input.sort_inputs([input1, input2, input3, input4]) == [
               input2,
               input3,
               input4,
               input1
             ]
    end
  end

  @sample_input_cbor "8282582038b60906a9084f4d975d83fa7c68659ceaf809bdc6adea4f533d902e386b539200825839000b8418cb378671165f749b4c0de768e703ff4834f216ccc1aa54c561e2c2c3c8bc797830e15677881deddbc3b1448f996ce5d56efaac80f11b00000002540be400"

  describe "Input parsing with Cbor Hex" do
    test "from_hex/1 returns Input struct if its valid" do
      assert %Sutra.Cardano.Transaction.Input{
               output: %Sutra.Cardano.Transaction.Output{
                 datum_raw: nil,
                 reference_script: nil,
                 datum: %Sutra.Cardano.Transaction.Datum{kind: :no_datum, value: nil},
                 value: %{"lovelace" => 10_000_000_000},
                 address: %Sutra.Cardano.Address{
                   stake_credential: %Sutra.Cardano.Address.Credential{
                     hash: "e2c2c3c8bc797830e15677881deddbc3b1448f996ce5d56efaac80f1",
                     credential_type: :vkey
                   },
                   payment_credential: %Sutra.Cardano.Address.Credential{
                     hash: "0b8418cb378671165f749b4c0de768e703ff4834f216ccc1aa54c561",
                     credential_type: :vkey
                   },
                   address_type: :shelley,
                   network: :testnet
                 }
               },
               output_reference: %Sutra.Cardano.Transaction.OutputReference{
                 output_index: 0,
                 transaction_id:
                   "38b60906a9084f4d975d83fa7c68659ceaf809bdc6adea4f533d902e386b5392"
               }
             } == Input.from_hex(@sample_input_cbor)
    end
  end
end
