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
end
