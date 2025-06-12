defmodule Sutra.Cardano.Transaction.Witness.VkeyWitnessTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Transaction.Witness
  alias Witness.VkeyWitness

  describe "Signature verification test" do
    @valid_extended_key_witness %{
      "tx_id" => "bcaeed39733e00db82a5492d5b4791de8dc7e8b4859dafe89ec3915304bd4f4b",
      "witness" => %VkeyWitness{
        signature:
          <<126, 246, 105, 22, 110, 207, 71, 64, 216, 202, 160, 41, 22, 4, 41, 123, 207, 223, 147,
            114, 59, 169, 53, 94, 102, 122, 115, 231, 98, 104, 94, 146, 214, 138, 144, 145, 191,
            208, 249, 243, 211, 161, 85, 212, 184, 138, 191, 182, 236, 206, 112, 21, 42, 31, 11,
            238, 252, 76, 129, 113, 122, 68, 173, 1>>,
        vkey:
          <<103, 192, 65, 234, 145, 25, 219, 89, 87, 247, 46, 224, 142, 70, 20, 99, 142, 130, 94,
            72, 41, 27, 43, 182, 181, 72, 136, 76, 14, 93, 198, 199>>
      }
    }

    @invalid_extended_key_witness %{
      "tx_id" => "bcaeed39733e00db82a5492d5b4791de8dc7e8b4859dafe89ec3915304bd4f4b",
      "witness" => %VkeyWitness{
        signature:
          <<188, 187, 105, 231, 62, 160, 28, 31, 117, 58, 226, 21, 251, 190, 42, 206, 26, 77, 197,
            103, 89, 229, 123, 13, 59, 34, 168, 143, 163, 82, 251, 38, 167, 91, 139, 204, 251, 33,
            72, 232, 53, 78, 20, 176, 117, 182, 174, 216, 59, 222, 57, 70, 67, 34, 12, 10, 235,
            202, 154, 250, 204, 202, 176, 6>>,
        vkey:
          <<152, 120, 40, 91, 107, 197, 127, 8, 136, 68, 127, 159, 230, 175, 147, 214, 72, 107,
            78, 184, 98, 13, 123, 165, 215, 145, 176, 175, 74, 129, 115, 245>>
      }
    }

    @valid_normal_ed25519_key %{
      "tx_id" => "c55fb9569f41c9e7cbced0e922db26b6b3846cd1daf4439fcbbbc24d97b9eabd",
      "witness" => %VkeyWitness{
        signature:
          <<186, 91, 23, 123, 208, 108, 71, 52, 55, 216, 190, 36, 8, 7, 73, 87, 188, 52, 65, 8,
            231, 133, 167, 25, 225, 234, 19, 67, 160, 83, 33, 80, 235, 157, 249, 109, 124, 182,
            100, 110, 239, 236, 247, 113, 162, 33, 218, 134, 152, 126, 93, 169, 204, 142, 205,
            110, 173, 59, 85, 110, 192, 53, 6, 5>>,
        vkey:
          <<114, 128, 218, 55, 175, 237, 184, 106, 158, 220, 38, 1, 75, 50, 51, 63, 72, 132, 231,
            162, 126, 51, 250, 69, 106, 251, 182, 8, 68, 100, 121, 155>>
      }
    }

    @invalid_normal_ed25519_key %{
      "tx_id" => "c55fb9569f41c9e7cbced0e922db26b6b3846cd1daf4439fcbbbc24d97b9eabd",
      "witness" => %VkeyWitness{
        signature:
          <<86, 169, 186, 42, 202, 195, 183, 70, 156, 133, 88, 103, 101, 149, 105, 222, 218, 38,
            174, 229, 179, 57, 190, 81, 137, 119, 129, 18, 60, 243, 19, 149, 233, 131, 116, 31,
            151, 67, 51, 63, 50, 239, 236, 7, 226, 251, 102, 201, 53, 234, 3, 156, 96, 60, 140,
            88, 68, 119, 9, 101, 26, 157, 77, 14>>,
        vkey:
          <<114, 128, 218, 55, 175, 237, 184, 106, 158, 220, 38, 1, 75, 50, 51, 63, 72, 132, 231,
            162, 126, 51, 250, 69, 106, 251, 182, 8, 68, 100, 121, 155>>
      }
    }
    test "verify_signature/2 returns :ok for correct signature" do
      assert Witness.verify_signature(
               @valid_extended_key_witness["witness"],
               @valid_extended_key_witness["tx_id"]
             ) == :ok

      assert Witness.verify_signature(
               @valid_normal_ed25519_key["witness"],
               @valid_normal_ed25519_key["tx_id"]
             ) == :ok
    end

    test "verify_signature/2 returns error for incorrect signature" do
      assert Witness.verify_signature(
               @invalid_extended_key_witness["witness"],
               @invalid_extended_key_witness["tx_id"]
             ) == {:error, :INVALID_SIGNATURE}

      assert Witness.verify_signature(
               @invalid_normal_ed25519_key["witness"],
               @invalid_normal_ed25519_key["tx_id"]
             ) == {:error, :INVALID_SIGNATURE}
    end
  end
end
