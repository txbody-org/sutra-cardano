defmodule Sutra.Cardano.Crypto.KeyTest do
  @moduledoc false

  use ExUnit.Case

  alias Sutra.Cardano.Address
  alias Sutra.Utils
  alias Sutra.Crypto.Key

  @mnemonic "assume pumpkin dream peace basket fire wage obscure once level prefer garden fresh more erode violin poet focus brush reflect famous neck city radar"

  @root_key Key.root_key_from_mnemonic(@mnemonic) |> Utils.ok_or(nil)

  @address %{
    # accountIndx<>AddrIndx => Bech32 Address
    "00" =>
      "addr_test1qrgz3u46lm5pyfpeps8ne5ufg2vzgrtapjrvmxer40nqmy42kd2muuyjwvpuma0eurxcs48z4u3p6lyuzpy5y8hwruqsgnd5vs",
    "01" =>
      "addr_test1qrqdvr4phlgyx6scqjpu2c7htqtdm5nu4pscdhl7eva6yaa2kd2muuyjwvpuma0eurxcs48z4u3p6lyuzpy5y8hwruqsr2l4vw",
    "10" =>
      "addr_test1qq33hkxdm302ffvv0a2rzxh3s0afcakt6zjxh72wpn04jcg6f6p4yuq6lyqsln794uxrlx7jtdyj97zv3f5patg9t5xs2zg4nc",
    "11" =>
      "addr_test1qp9xh5yg8pu9fs42xfhcvzewuhtz6pup96u9x0dzz0ex4sq6f6p4yuq6lyqsln794uxrlx7jtdyj97zv3f5patg9t5xscwpfgl"
  }

  describe "derive address From Key" do
    test "address/4 derives address from root Key" do
      Key.address(@root_key, :preprod, 0, 0)

      assert @address["00"] ==
               Key.address(@root_key, :preprod, 0, 0)
               |> Utils.when_ok(&Address.to_bech32/1)

      assert @address["01"] ==
               Key.address(@root_key, :preprod, 0, 1)
               |> Utils.when_ok(&Address.to_bech32/1)

      assert @address["10"] ==
               Key.address(@root_key, :preprod, 1, 0)
               |> Utils.when_ok(&Address.to_bech32/1)

      assert @address["11"] ==
               Key.address(@root_key, :preprod, 1, 1)
               |> Utils.when_ok(&Address.to_bech32/1)
    end

    test "derive address from Ed25519key" do
      assert addr =
               Key.from_bech32(
                 "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"
               )
               |> Key.address(:preprod)
               |> Address.to_bech32()

      assert addr == "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"
    end
  end
end
