defmodule Sutra.Cardano.Transaction.TxBuilder.TxBuilderTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.TxBuilder
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
               collateral_inputs: [],
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

    test "add_input/2 sets inputs and redeemer_lookup" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output:
          Output.new(
            Address.from_script(sample_plutus_script(), :preprod),
            Asset.from_lovelace(100)
          )
      }

      assert %TxBuilder{inputs: inputs} =
               builder =
               new_tx()
               |> add_input([input], witness: sample_plutus_script(), redeemer: Data.void())

      assert inputs == [input]

      assert builder.redeemer_lookup == %{
               {:spend, "tx-id-1#0"} => Data.void()
             }
    end

    test "add_input/2 sets inputs without redeemer_lookup" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output: Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(100))
      }

      assert %TxBuilder{inputs: inputs} = builder = new_tx() |> add_input([input])

      assert inputs == [input]

      assert builder.redeemer_lookup == %{}
    end

    test "add_output/2 adds output to tx Builder" do
      output = Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(200))

      assert %TxBuilder{} =
               builder =
               new_tx()
               |> add_output(output)

      assert builder.outputs == [output]
      assert builder.plutus_data == %{}
    end

    test "add_output/3 adds output with datum to tx Builder" do
      output =
        Output.new(
          Address.from_bech32(@addr1),
          Asset.from_lovelace(200),
          datum: Datum.inline(Data.encode(24))
        )

      assert %TxBuilder{} =
               builder =
               new_tx()
               |> add_output(output)

      assert builder.outputs == [
               %Output{
                 output
                 | datum: %Datum{kind: :inline_datum, value: Data.encode(24)}
               }
             ]

      assert builder.plutus_data == %{}
    end

    test "add_output/3 adds output with as_hash datum to tx Builder & setup plutus data lookup" do
      output =
        Output.new(
          Address.from_bech32(@addr1),
          Asset.from_lovelace(200),
          datum: Datum.datum_hash(Data.encode(24) |> Blake2b.blake2b_256()),
          datum_raw: 24
        )

      assert %TxBuilder{} =
               builder =
               new_tx()
               |> add_output(output)

      assert builder.outputs == [
               %Output{
                 output
                 | datum: %Datum{kind: :datum_hash, value: Blake2b.blake2b_256(Data.encode(24))}
               }
             ]

      assert builder.plutus_data == %{output.datum.value => 24}
    end

    test "add_output/2 creates output with asset and provided address" do
      assert %TxBuilder{} =
               builder =
               new_tx() |> add_output(Address.from_bech32(@addr1), Asset.from_lovelace(150))

      assert builder.outputs == [
               Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(150))
             ]
    end

    test "datum can also be passed as option to add_output/3" do
      assert %TxBuilder{outputs: [output]} =
               builder =
               new_tx()
               |> add_output(
                 Address.from_bech32(@addr1),
                 Asset.from_lovelace(150),
                 {:datum_hash, "some-datum"}
               )

      assert output ==
               Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(150),
                 datum: %Datum{
                   kind: :datum_hash,
                   value: Blake2b.blake2b_256(Data.encode("some-datum"))
                 },
                 datum_raw: %CBOR.Tag{tag: :bytes, value: "some-datum"}
               )

      assert builder.plutus_data == %{
               output.datum.value => %CBOR.Tag{tag: :bytes, value: "some-datum"}
             }
    end

    test "valid_from/2 setup tx begin validatity interval" do
      assert %TxBuilder{valid_from: 24} = new_tx() |> valid_from(24)
    end

    test "valid_from/2 setup tx ttl" do
      assert %TxBuilder{valid_to: 150} = new_tx() |> valid_to(150)
    end

    test "add_reference_inputs/2 allows input Utxos to put as reference inputs" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output: Output.new(Address.from_bech32(@addr1), Asset.from_lovelace(100))
      }

      assert %TxBuilder{ref_inputs: inputs} = new_tx() |> add_reference_inputs([input])

      assert inputs == [input]
    end

    test "add_reference_inputs/2 with used ref script puts script in used_script" do
      input = %Input{
        output_reference: %OutputReference{transaction_id: "tx-id-1", output_index: 0},
        output:
          Output.new(
            Address.from_bech32(@addr1),
            Asset.from_lovelace(100),
            reference_script: sample_plutus_script()
          )
      }

      policy_id = Script.hash_script(sample_plutus_script())

      assert %TxBuilder{ref_inputs: inputs, used_scripts: used_scripts} =
               new_tx()
               |> add_reference_inputs([input])
               |> mint_asset(
                 policy_id,
                 %{"" => 1},
                 :ref_inputs,
                 Data.void()
               )
               |> add_output(Address.from_bech32(@addr1), %{policy_id => %{"" => 1}})

      assert inputs == [input]
      assert MapSet.to_list(used_scripts) == [:plutus_v1]
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

      assert {:error, [%{key: :missing_minting_policy, value: error_val}]} =
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 },
                 :ref_inputs,
                 Data.void()
               )
               |> set_protocol_params(sample_protocol_params())
               |> add_output(Address.from_bech32(@addr2), %{
                 policy_id => %{Base.encode16("sample-script") => 1}
               })
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )

      assert error_val == policy_id
    end

    test "build_tx/3 fails if redeemer is not available for plutus minting policy" do
      script = sample_plutus_script()
      policy_id = Script.hash_script(script)

      assert {:error, [%{value: error_value, key: :invalid_redeemer_for_policy}]} =
               new_tx()
               |> mint_asset(
                 policy_id,
                 %{
                   Base.encode16("sample-script") => 1
                 },
                 script,
                 nil
               )
               |> add_output(Address.from_bech32(@addr2), %{
                 policy_id => %{Base.encode16("sample-script") => 1}
               })
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )

      assert error_value == policy_id
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
                 },
                 script,
                 nil
               )
               |> add_output(Address.from_bech32(@addr2), %{
                 policy_id => %{Base.encode16("sample-script") => 1}
               })
               |> add_output(Address.from_bech32(@addr2), %{
                 policy_id => %{Base.encode16("another-token") => 1}
               })
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
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
                 },
                 script,
                 nil
               )
               |> add_output(Address.from_bech32(@addr2), %{
                 policy_id => %{Base.encode16("another-token") => 1}
               })
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
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
                 },
                 script,
                 nil
               )
               |> add_output(Address.from_bech32(@addr2), %{
                 policy_id => %{Base.encode16("sample-script") => 1}
               })
               |> set_protocol_params(sample_protocol_params())
               |> set_wallet_address([Address.from_bech32(@addr1)])
               |> use_provider(Kupogmios)
               |> build_tx(
                 wallet_utxos: wallet_utxos(),
                 slot_config: SlotConfig.fetch_slot_config(:preprod)
               )
    end
  end
end
