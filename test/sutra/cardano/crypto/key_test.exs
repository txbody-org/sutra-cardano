defmodule Sutra.Cardano.Crypto.KeyTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address
  alias Sutra.Crypto.Key
  alias Sutra.Utils

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

  @xprv "xprv1cplmptgu8v8ppse7q0vcvraydc3l7wlvrxjq5t4x0dsce7jad98rudhksqp7jr4tfdmdzgytq4qh9m53q5nrh673pwyfqwmjenetrck92ngu4etf8grs594tc5euxldqw39u0cezqj9auq022urj6u3pxgj0yxns"

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
               |> Utils.when_ok(&Utils.identity/1)
               |> Key.address(:preprod)
               |> Utils.when_ok(&Address.to_bech32/1)

      assert addr == "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"
    end

    test "derive addres from xprv Bech32 Key" do
      assert addr =
               Key.from_bech32(@xprv)
               |> Utils.when_ok(&Utils.identity/1)
               |> Key.address(:preprod)
               |> Utils.when_ok(&Address.to_bech32/1)

      assert addr ==
               "addr_test1qrd72klh2n7y7h8v052hl8jewyuzq53yep97u904jzckx93tkqyq4e0wcgvykc6dxzd66kt9796mupn92q2py09cz3as42u3zd"
    end
  end

  describe "Sign Payload Using Key" do
    test "sign/2 gives signature for extended Keys" do
      assert payload =
               Base.decode16!("282aa52c7824c48576138b96924a91f2eea5de99155932196761ea330fb5c51c",
                 case: :mixed
               )

      assert {:ok, extended_key} = Key.derive_child(@root_key, 0, 0)
      assert signature = Key.sign(extended_key, payload)

      assert Base.encode16(signature, case: :lower) ==
               "b09380f76cc08c93596f2f5cf0fa41f188e44cdec09f7c052712e47c5bd3f0d2cede3ffb3ebd51c8a29b72377801be53e7aa9b4a0cf3fb32584d299c5b078209"
    end

    test "sign/2 gives signature for Ed25519key " do
      assert payload =
               Base.decode16!("93cb072c413e32a474460ec532f730fd5adbddfe5c92fd3df3c92b5c3c2f108c",
                 case: :mixed
               )

      assert {:ok, ed25519_key} =
               Key.from_bech32(
                 "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"
               )

      assert signature = Key.sign(ed25519_key, payload)

      assert Base.encode16(signature, case: :lower) ==
               "3c7a0018e581f692170f5fb8abcf2d1e4c5438317874f53f006d976d17677cae5cfca0cc197196c3fa6ff08a08bbaee660077bf790a77ed4ab27fbedf6f89908"
    end
  end
end
