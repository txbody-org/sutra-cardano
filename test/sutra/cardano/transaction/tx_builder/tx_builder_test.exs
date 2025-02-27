defmodule Sutra.Cardano.Transaction.TxBuilder.TxBuilderTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.TxBuilder
  alias Sutra.Cardano.Transaction.TxBuilder.Error.NoScriptWitness
  alias Sutra.Data
  alias Sutra.Provider.KoiosProvider
  alias Sutra.Provider.Kupogmios
  alias Sutra.SlotConfig

  import Sutra.Cardano.Transaction.TxBuilder
  import Sutra.Test.Support.BuilderSupport

  @addr1 "addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5pnz75xxcrzqf96k"
  @addr2 "addr1w8phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtcyjy7wx"

  describe "TxBuilder Common Function" do
    test "new_tx/0 initialize TxBuilder" do
      assert %TxBuilder{
               mints: %{},
               ref_inputs: [],
               inputs: [],
               outputs: [],
               metadata: nil,
               collateral_input: nil,
               redeemer_lookup: %{},
               valid_from: nil,
               valid_to: nil
             } = builder = new_tx()

      assert builder.required_signers == MapSet.new()
      assert builder.config == %TxBuilder.TxConfig{}
    end

    test "use_provider/2 overrides provider" do
      assert %TxBuilder{config: %TxBuilder.TxConfig{provider: KoiosProvider}} =
               new_tx() |> use_provider(KoiosProvider)
    end

    test "set_wallet_address/2 set wallet address to sign & fetch utxos" do
      assert %TxBuilder{config: %TxBuilder.TxConfig{} = cfg} =
               new_tx() |> set_wallet_address(Address.from_bech32(@addr1))

      assert cfg.wallet_address == [Address.from_bech32(@addr1)]

      assert %TxBuilder{config: %TxBuilder.TxConfig{} = cfg} =
               new_tx()
               |> set_wallet_address([Address.from_bech32(@addr1), Address.from_bech32(@addr2)])

      assert cfg.wallet_address == [Address.from_bech32(@addr1), Address.from_bech32(@addr2)]
    end

    test "spend/3 sets inputs and redeemer_lookup" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output: Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(100))
      }

      assert %TxBuilder{inputs: inputs} = builder = new_tx() |> spend([input], Data.void())

      assert inputs == [input]

      assert builder.redeemer_lookup == %{
               {:spend, "tx-id-1#0"} => Data.void()
             }
    end

    test "spend/2 sets inputs without redeemer_lookup" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output: Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(100))
      }

      assert %TxBuilder{inputs: inputs} = builder = new_tx() |> spend([input])

      assert inputs == [input]

      assert builder.redeemer_lookup == %{}
    end

    test "put_output/2 adds output to tx Builder" do
      output = Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(200))

      assert %TxBuilder{} =
               builder =
               new_tx()
               |> put_output(output)

      assert builder.outputs == [output]
      assert builder.plutus_data == []
    end

    test "put_output/3 adds output with datum to tx Builder" do
      output = Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(200))

      assert %TxBuilder{} =
               builder =
               new_tx()
               |> put_output(output, {:inline, Data.encode(24)})

      assert builder.outputs == [
               %Output{output | datum: %Datum{kind: :inline_datum, value: Data.encode(24)}}
             ]

      assert builder.plutus_data == []
    end

    test "put_output/3 adds output with as_hash datum to tx Builder & setup plutus data lookup" do
      output = Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(200))

      assert %TxBuilder{} =
               builder =
               new_tx()
               |> put_output(output, {:as_hash, Data.encode(24)})

      assert builder.outputs == [
               %Output{
                 output
                 | datum: %Datum{kind: :datum_hash, value: Blake2b.blake2b_256(Data.encode(24))}
               }
             ]

      assert builder.plutus_data == [24]
    end

    test "pay_to_address/3 creates output with asset and provided address" do
      assert %TxBuilder{} = builder = new_tx() |> pay_to_address(@addr1, Asset.from_lovelace(150))

      assert builder.outputs == [
               Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(150))
             ]
    end

    test "datum can also be passed as option to pay_to_address/3" do
      assert %TxBuilder{} =
               builder =
               new_tx()
               |> pay_to_address(@addr1, Asset.from_lovelace(150),
                 datum: {:as_hash, Data.encode("some-datum")}
               )

      assert builder.outputs == [
               Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(150), %Datum{
                 kind: :datum_hash,
                 value: Blake2b.blake2b_256(Data.encode("some-datum"))
               })
             ]

      assert builder.plutus_data == [%CBOR.Tag{tag: :bytes, value: "some-datum"}]
    end

    test "attach_script/2 attach plutus and native script to script lookup" do
      plutus_script = Script.new(Base.encode16("plutus-script"), :plutus_v3)

      native_script =
        NativeScript.from_json(%{
          "type" => "all",
          "scripts" => [
            %{"type" => "sig", "keyHash" => "key1"}
          ]
        })

      assert %TxBuilder{scripts_lookup: scripts_lookup} =
               new_tx() |> attach_script(plutus_script) |> attach_script(native_script)

      assert scripts_lookup.native == %{
               "5118f9e77a0fa0f527b102276e829c9e651a9689cf466ad00bec5e06" =>
                 %NativeScript.ScriptAll{
                   scripts: [
                     %NativeScript.ScriptPubkey{pubkey_hash: "key1"}
                   ]
                 }
             }

      assert scripts_lookup.plutus_v3 == %{
               "90b3c94c07c46471c0a2ac773fd9331caaabdb84a004b5715291d6f9" => %Script{
                 script_type: :plutus_v3,
                 data: "706C757475732D736372697074"
               }
             }
    end

    test "mint_asset/3 allows minting assets" do
      assert %TxBuilder{mints: mints, redeemer_lookup: redeemer} =
               new_tx()
               |> mint_asset("policy-1", %{"token-1" => 1})
               |> mint_asset("policy-2", %{"token-2" => 1}, Data.void())

      assert mints == %{
               "policy-1" => %{"token-1" => 1},
               "policy-2" => %{"token-2" => 1}
             }

      assert redeemer == %{
               {:mint, "policy-2"} => Data.void()
             }
    end

    test "valid_from/2 setup tx begin validatity interval" do
      assert %TxBuilder{valid_from: 24} = new_tx() |> valid_from(24)
    end

    test "valid_from/2 setup tx ttl" do
      assert %TxBuilder{valid_to: 150} = new_tx() |> valid_to(150)
    end

    test "reference_inputs/2 allows input Utxos to put as reference inputs" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output: Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(100))
      }

      assert %TxBuilder{ref_inputs: inputs} = new_tx() |> reference_inputs([input])

      assert inputs == [input]
    end

    test "reference_inputs/2 with ref script puts script in script_lookup" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output:
          Output.new(
            Address.from_bech32(@addr1),
            Asset.from_lovelace(100),
            nil,
            Script.new("sample-script", :plutus_v3)
          )
      }

      assert %TxBuilder{ref_inputs: inputs, scripts_lookup: %{plutus_v3: v3_script}} =
               new_tx() |> reference_inputs([input])

      assert inputs == [input]

      assert v3_script == %{
               Script.hash_script(input.output.reference_script) => true
             }
    end
  end

  describe "build TX Test" do
    def wallet_utxos do
      [
        input(%{"lovelace" => 500_000}),
        input(
          Asset.add(%{}, Script.hash_script(%Script{script_type: :native, data: "a1"}), "aeo2", 1)
        ),
        input(%{"lovelace" => 1_000_000_000})
      ]
    end

    test "build_tx/3 fails if minting policy is missing" do
      native_script = sample_native_script()
      policy_id = Script.hash_script(native_script)

      assert {:error, %NoScriptWitness{} = error} =
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 },
                 Data.void()
               )
               |> set_protocol_params(sample_protocol_params())
               |> pay_to_address(@addr2, %{policy_id => %{Base.encode16("sample-script") => 1}})
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )

      assert error.reason =~
               "No Script witness found for Script #{policy_id}"
    end

    test "build_tx/3 fails if redeemer is not available for plutus minting policy" do
      script = sample_plutus_script()
      policy_id = Script.hash_script(script)

      assert {:error, "Redeemer Missing for Mint, PolicyId: #{policy_id}"} ==
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 }
               )
               |> pay_to_address(@addr2, %{policy_id => %{Base.encode16("sample-script") => 1}})
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> attach_script(script)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )
    end

    test "build_tx/3 fails when inputs cannot cover outputs" do
      script = sample_native_script()
      policy_id = Script.hash_script(script)

      assert {:error, error} =
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 }
               )
               |> pay_to_address(@addr2, %{policy_id => %{Base.encode16("sample-script") => 1}})
               |> pay_to_address(@addr2, %{policy_id => %{Base.encode16("another-token") => 1}})
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> attach_script(script)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )

      assert error.reason =~
               "Couldn't find utxos to cover \n %{\"477e52b3116b62fe8cd34a312615f5fcd678c94e1d6cdb86c1a3964c\" => %{\"616E6F746865722D746F6B656E\" => 1}"
    end

    test "build_tx/3 fails if minted token is not present in output" do
      script = sample_native_script()
      policy_id = Script.hash_script(script)

      assert {:error, "No Output Found with Minting Policies: #{policy_id}"} ==
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 }
               )
               |> pay_to_address(@addr2, %{policy_id => %{Base.encode16("another-token") => 1}})
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> attach_script(script)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )
    end

    test "build_tx/3 returns Unsigned Tx" do
      script = sample_native_script()
      policy_id = Script.hash_script(script)

      assert {:ok, %Transaction{}} =
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 }
               )
               |> pay_to_address(@addr2, %{policy_id => %{Base.encode16("sample-script") => 1}})
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> attach_script(script)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )
    end
  end
end
