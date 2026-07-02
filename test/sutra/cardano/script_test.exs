defmodule Sutra.Cardano.ScriptTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Script

  @script_hex "4e4d01000033222220051200120011"

  describe "script_ref round trip" do
    for {script_type, tag} <- [plutus_v1: 1, plutus_v2: 2, plutus_v3: 3, plutus_v4: 4] do
      test "encodes and decodes #{script_type} script ref (tag #{tag})" do
        script = Script.new(unquote(@script_hex), unquote(script_type))

        assert %Script{script_type: unquote(script_type), data: unquote(@script_hex)} =
                 script
                 |> Script.to_script_ref()
                 |> Script.from_script_ref()
      end
    end
  end

  describe "hash_script/1" do
    test "hashes plutus_v4 script with 0x04 prefix" do
      script = Script.new(@script_hex, :plutus_v4)

      expected =
        (<<4>> <> Sutra.Utils.safe_base16_decode(@script_hex))
        |> Sutra.Blake2b.blake2b_224()

      assert Script.hash_script(script) == expected
    end
  end
end
