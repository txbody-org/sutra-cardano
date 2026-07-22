defmodule Sutra.Cardano.Transaction.TxBuilder.ProposeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.GovAction
  alias Sutra.Cardano.Gov.ProposalProcedure
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.TxBody

  import Sutra.Cardano.Transaction.TxBuilder
  import Sutra.Test.Support.BuilderSupport

  @reward_hex "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
  @hash32 "7de1a14fd91a5c307c9816fdbc970bdd724c62c7ea1eb2ba97ac89ee0fb9fb7a"
  @anchor %{url: "https://example.com/meta.json", hash: @hash32}

  describe "propose/3" do
    test "records a proposal with an explicit deposit" do
      builder =
        new_tx()
        |> propose(GovAction.info(),
          reward_account: @reward_hex,
          anchor: @anchor,
          deposit: 100_000_000
        )

      assert [{%ProposalProcedure{} = procedure, nil}] = builder.proposals
      assert procedure.deposit == Asset.from_lovelace(100_000_000)
      assert procedure.reward_account == @reward_hex
      assert procedure.anchor == @anchor
      assert %GovAction.InfoAction{} = procedure.gov_action
    end

    test "leaves deposit nil when omitted (filled from protocol params at build)" do
      builder =
        new_tx() |> propose(GovAction.info(), reward_account: @reward_hex, anchor: @anchor)

      assert [{%ProposalProcedure{deposit: nil}, nil}] = builder.proposals
    end

    test "accepts a reward Address and normalizes it to reward-account hex" do
      addr = %Address{
        network: :testnet,
        address_type: :reward,
        payment_credential: nil,
        stake_credential: %Credential{credential_type: :vkey, hash: String.duplicate("ab", 28)}
      }

      expected = Address.Parser.encode(addr) |> Base.encode16(case: :lower)

      builder = new_tx() |> propose(GovAction.info(), reward_account: addr, anchor: @anchor)
      assert [{%ProposalProcedure{reward_account: ^expected}, nil}] = builder.proposals
    end

    test "multiple proposals accumulate" do
      builder =
        new_tx()
        |> propose(GovAction.info(), reward_account: @reward_hex, anchor: @anchor)
        |> propose(GovAction.no_confidence(), reward_account: @reward_hex, anchor: @anchor)

      assert length(builder.proposals) == 2
    end

    test "a guardrails script witness is registered as a used script" do
      script = sample_plutus_script()
      action = GovAction.treasury_withdrawals(%{@reward_hex => 1_000_000})

      builder =
        new_tx()
        |> propose(action, reward_account: @reward_hex, anchor: @anchor, witness: script)

      assert builder.script_lookup[Script.hash_script(script)] == script
      assert MapSet.member?(builder.used_scripts, :plutus_v1)
    end
  end

  describe "proposal_procedures round trip through TxBody" do
    test "encode + decode preserves the proposals" do
      procedures = [
        %ProposalProcedure{
          deposit: Asset.from_lovelace(100_000_000),
          reward_account: @reward_hex,
          gov_action: GovAction.info(),
          anchor: @anchor
        },
        %ProposalProcedure{
          deposit: Asset.from_lovelace(100_000_000),
          reward_account: @reward_hex,
          gov_action: GovAction.treasury_withdrawals(%{@reward_hex => 5_000_000}),
          anchor: @anchor
        }
      ]

      body = %TxBody{
        inputs: [%OutputReference{transaction_id: @hash32, output_index: 0}],
        outputs: [
          Output.new(Address.from_bech32(sample_address()), Asset.from_lovelace(2_000_000))
        ],
        fee: Asset.from_lovelace(170_000),
        proposal_procedures: procedures
      }

      decoded = body |> TxBody.to_cbor() |> TxBody.decode()
      assert decoded.proposal_procedures == procedures
    end
  end
end
