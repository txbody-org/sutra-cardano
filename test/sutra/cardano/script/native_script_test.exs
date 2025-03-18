defmodule Sutra.Cardano.Script.NativeScriptTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Script.NativeScript

  # Examples are from
  # https://github.com/IntersectMBO/cardano-node/blob/1.26.1-with-cardano-cli/doc/reference/simple-scripts.md#json-script-syntax

  @script_all %{
    "type" => "all",
    "scripts" => [
      %{
        "type" => "sig",
        "keyHash" => "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
      },
      %{
        "type" => "sig",
        "keyHash" => "a687dcc24e00dd3caafbeb5e68f97ca8ef269cb6fe971345eb951756"
      },
      %{
        "type" => "sig",
        "keyHash" => "0bd1d702b2e6188fe0857a6dc7ffb0675229bab58c86638ffa87ed6d"
      }
    ]
  }

  @script_any %{
    "type" => "any",
    "scripts" => [
      %{
        "type" => "sig",
        "keyHash" => "d92b712d1882c3b0f75b6f677e0b2cbef4fbc8b8121bb9dde324ff09"
      },
      %{
        "type" => "sig",
        "keyHash" => "4d780ed1bfc88cbd4da3f48de91fe728c3530d662564bf5a284b5321"
      },
      %{
        "type" => "sig",
        "keyHash" => "3a94d6d4e786a3f5d439939cafc0536f6abc324fb8404084d6034bf8"
      }
    ]
  }

  @script_atleast %{
    "type" => "atLeast",
    "required" => 2,
    "scripts" => [
      %{
        "type" => "sig",
        "keyHash" => "2f3d4cf10d0471a1db9f2d2907de867968c27bca6272f062cd1c2413"
      },
      %{
        "type" => "sig",
        "keyHash" => "f856c0c5839bab22673747d53f1ae9eed84afafb085f086e8e988614"
      },
      %{
        "type" => "sig",
        "keyHash" => "b275b08c999097247f7c17e77007c7010cd19f20cc086ad99d398538"
      }
    ]
  }

  # Burn script from https://www.cardano-tools.io/burn-address
  @burn_script %{
    "type" => "all",
    "scripts" => [
      %{
        "type" => "before",
        "slot" => 0
      }
    ]
  }

  describe "to_script/1 " do
    test "valid burn address derived from burn script" do
      assert bech32_addr =
               NativeScript.from_json(@burn_script)
               |> NativeScript.to_script()
               |> Address.from_script(:mainnet)
               |> Address.to_bech32()

      assert bech32_addr == "addr1wxa7ec20249sqg87yu2aqkqp735qa02q6yd93u28gzul93ghspjnt"
    end
  end

  describe "Native Script from Json" do
    test "from_json/1 returns Native Script for script type all " do
      assert %NativeScript.ScriptAll{scripts: other_scripts} = NativeScript.from_json(@script_all)

      assert other_scripts == [
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
               },
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "a687dcc24e00dd3caafbeb5e68f97ca8ef269cb6fe971345eb951756"
               },
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "0bd1d702b2e6188fe0857a6dc7ffb0675229bab58c86638ffa87ed6d"
               }
             ]
    end

    test "from_json/1 returns Native script for script type any" do
      assert %NativeScript.ScriptAny{scripts: scripts} = NativeScript.from_json(@script_any)

      assert scripts == [
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "d92b712d1882c3b0f75b6f677e0b2cbef4fbc8b8121bb9dde324ff09"
               },
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "4d780ed1bfc88cbd4da3f48de91fe728c3530d662564bf5a284b5321"
               },
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "3a94d6d4e786a3f5d439939cafc0536f6abc324fb8404084d6034bf8"
               }
             ]
    end

    test "from_json/1 returns Native script for script type atLeast" do
      assert %NativeScript.ScriptNOfK{scripts: scripts, n: 2} =
               NativeScript.from_json(@script_atleast)

      assert scripts == [
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "2f3d4cf10d0471a1db9f2d2907de867968c27bca6272f062cd1c2413"
               },
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "f856c0c5839bab22673747d53f1ae9eed84afafb085f086e8e988614"
               },
               %Sutra.Cardano.Script.NativeScript.ScriptPubkey{
                 pubkey_hash: "b275b08c999097247f7c17e77007c7010cd19f20cc086ad99d398538"
               }
             ]
    end
  end
end
