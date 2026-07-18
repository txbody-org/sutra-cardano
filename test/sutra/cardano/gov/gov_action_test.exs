defmodule Sutra.Cardano.Gov.GovActionTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.GovAction
  alias Sutra.Cardano.Gov.GovAction.HardForkInitiation
  alias Sutra.Cardano.Gov.GovAction.InfoAction
  alias Sutra.Cardano.Gov.GovAction.NewConstitution
  alias Sutra.Cardano.Gov.GovAction.NoConfidence
  alias Sutra.Cardano.Gov.GovAction.TreasuryWithdrawals
  alias Sutra.Cardano.Gov.GovAction.UpdateCommittee
  alias Sutra.Cardano.Gov.ProposalProcedure
  alias Sutra.Cardano.Transaction.OutputReference

  @action_tx "130663f385984456f5d3f9b1c7eda359f942f325a30218cadeb23413ddaaf6b8"
  @reward_acc "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
  @hash32 "7de1a14fd91a5c307c9816fdbc970bdd724c62c7ea1eb2ba97ac89ee0fb9fb7a"
  @cold_cred %Credential{credential_type: :vkey, hash: @reward_acc}
  @anchor %{url: "https://example.com/meta.json", hash: @hash32}

  defp prev_action, do: %OutputReference{transaction_id: @action_tx, output_index: 0}

  describe "GovAction round trips through to_cbor/1 -> decode/1" do
    test "every gov action variant round trips" do
      actions = [
        GovAction.info(),
        GovAction.no_confidence(),
        GovAction.no_confidence(prev_action()),
        GovAction.hard_fork(11, 0),
        GovAction.hard_fork(11, 0, prev_action()),
        GovAction.treasury_withdrawals(%{@reward_acc => 1_000_000}),
        GovAction.treasury_withdrawals(%{@reward_acc => 1_000_000},
          guardrails_script_hash: @reward_acc
        ),
        GovAction.new_constitution(@anchor),
        GovAction.update_committee(%{@cold_cred => 500}, [@cold_cred], {1, 2})
      ]

      for action <- actions do
        assert action == action |> GovAction.to_cbor() |> GovAction.decode()
      end
    end

    test "encodes each action with the correct tag" do
      assert [6] = GovAction.to_cbor(%InfoAction{})
      assert [3 | _] = GovAction.to_cbor(%NoConfidence{gov_action_id: nil})
      assert [1 | _] = GovAction.to_cbor(GovAction.hard_fork(11, 0))
      assert [2 | _] = GovAction.to_cbor(GovAction.treasury_withdrawals(%{@reward_acc => 1}))
      assert [4 | _] = GovAction.to_cbor(GovAction.update_committee(%{}, [], {1, 2}))
      assert [5 | _] = GovAction.to_cbor(GovAction.new_constitution(@anchor))
    end

    test "typed struct field values survive the round trip" do
      action = GovAction.treasury_withdrawals(%{@reward_acc => 1_000_000})
      decoded = action |> GovAction.to_cbor() |> GovAction.decode()

      assert %TreasuryWithdrawals{withdrawals: %{@reward_acc => %{"lovelace" => 1_000_000}}} =
               decoded
    end

    test "hard fork keeps the protocol version tuple" do
      assert %HardForkInitiation{protocol_version: {11, 0}} =
               GovAction.hard_fork(11, 0) |> GovAction.to_cbor() |> GovAction.decode()
    end

    test "update committee keeps members, removals and quorum" do
      decoded =
        GovAction.update_committee(%{@cold_cred => 500}, [@cold_cred], {1, 2})
        |> GovAction.to_cbor()
        |> GovAction.decode()

      assert %UpdateCommittee{
               added_members: %{@cold_cred => 500},
               removed_members: [@cold_cred],
               quorum: {1, 2}
             } = decoded
    end

    test "new constitution keeps anchor and guardrails" do
      decoded =
        GovAction.new_constitution(@anchor, guardrails_script_hash: @reward_acc)
        |> GovAction.to_cbor()
        |> GovAction.decode()

      assert %NewConstitution{anchor: @anchor, guardrails_script_hash: @reward_acc} = decoded
    end
  end

  describe "ProposalProcedure round trip" do
    test "encodes and decodes a full proposal" do
      procedure = %ProposalProcedure{
        deposit: Asset.from_lovelace(100_000_000),
        reward_account: @reward_acc,
        gov_action: GovAction.info(),
        anchor: @anchor
      }

      assert procedure == procedure |> ProposalProcedure.to_cbor() |> ProposalProcedure.decode()
    end
  end
end
