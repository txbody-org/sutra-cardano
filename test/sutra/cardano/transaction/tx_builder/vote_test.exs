defmodule Sutra.Cardano.Transaction.TxBuilder.VoteTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Gov
  alias Sutra.Cardano.Gov.Voter
  alias Sutra.Cardano.Gov.VotingProcedure
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Data.Plutus.Constr

  import Sutra.Cardano.Transaction.TxBuilder
  import Sutra.Test.Support.BuilderSupport

  @drep_hash "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d"
  @pool_hash "9ed23a4a839826d08d7d10f277a91f0e2373ea90251fb33664d52c94"
  @action_tx "130663f385984456f5d3f9b1c7eda359f942f325a30218cadeb23413ddaaf6b8"

  defp action_ref(index), do: %OutputReference{transaction_id: @action_tx, output_index: index}

  describe "Gov voter constructors" do
    test "drep_voter/1 accepts a Credential, a Drep, and a raw key hash" do
      cred = %Credential{credential_type: :vkey, hash: @drep_hash}

      assert %Voter{voter_type: :drep, credential: ^cred} = Gov.drep_voter(cred)
      assert %Voter{voter_type: :drep, credential: ^cred} = Gov.drep_voter(@drep_hash)

      assert %Voter{voter_type: :drep, credential: %Credential{credential_type: :script}} =
               Gov.drep_voter(Drep.script_drep("aabb"))
    end

    test "committee_voter/1 and stake_pool_voter/1" do
      assert %Voter{voter_type: :committee_hot} = Gov.committee_voter(@drep_hash)
      assert %Voter{voter_type: :stake_pool, credential: %Credential{credential_type: :vkey}} =
               Gov.stake_pool_voter(@pool_hash)
    end
  end

  describe "vote/5" do
    test "accumulates a key-credential vote (no redeemer wiring)" do
      voter = Gov.drep_voter(@drep_hash)
      action = Gov.gov_action_id(@action_tx, 0)

      builder = new_tx() |> vote(voter, action, :yes)

      assert %{^voter => %{^action => %VotingProcedure{vote: :yes, anchor: nil}}} = builder.votes
      assert builder.redeemer_lookup == %{}
      assert builder.errors == []
    end

    test "accepts an OutputReference to identify the action, plus an anchor" do
      voter = Gov.stake_pool_voter(@pool_hash)
      anchor = %{url: "https://example.com/meta.json", hash: "aabbcc"}

      builder = new_tx() |> vote(voter, action_ref(2), :no, anchor: anchor)

      action = action_ref(2)
      assert %{^voter => %{^action => %VotingProcedure{vote: :no, anchor: ^anchor}}} = builder.votes
    end

    test "accepts an Input to identify the action" do
      voter = Gov.drep_voter(@drep_hash)
      input = %Input{output_reference: action_ref(3), output: nil}

      builder = new_tx() |> vote(voter, input, :yes)

      action = action_ref(3)
      assert %{^voter => %{^action => %VotingProcedure{vote: :yes}}} = builder.votes
    end

    test "the same voter voting on multiple actions is merged" do
      voter = Gov.drep_voter(@drep_hash)

      builder =
        new_tx()
        |> vote(voter, action_ref(0), :yes)
        |> vote(voter, action_ref(1), :abstain)

      assert map_size(builder.votes[voter]) == 2
    end

    test "script DRep vote wires the script witness and redeemer" do
      script = sample_plutus_script()
      script_hash = Script.hash_script(script)
      voter = Gov.drep_voter(%Credential{credential_type: :script, hash: script_hash})
      redeemer = %Constr{index: 0, fields: []}

      builder = new_tx() |> vote(voter, action_ref(0), :yes, witness: script, redeemer: redeemer)

      assert builder.errors == []
      assert builder.script_lookup[script_hash] == script
      assert Map.get(builder.redeemer_lookup, {:vote, voter}) == redeemer
      assert MapSet.member?(builder.used_scripts, :plutus_v1)
    end

    test "script DRep vote missing a redeemer records an error" do
      script = sample_plutus_script()

      voter =
        Gov.drep_voter(%Credential{credential_type: :script, hash: Script.hash_script(script)})

      builder = new_tx() |> vote(voter, action_ref(0), :yes, witness: script)

      assert [%{key: :invalid_redeemer, value: ^voter} | _] = builder.errors
    end

    test "script voter with no witness at all records a missing-script error" do
      voter =
        Gov.drep_voter(%Credential{credential_type: :script, hash: String.duplicate("ab", 28)})

      builder = new_tx() |> vote(voter, action_ref(0), :yes)

      assert [%{key: :missing_script_witness, value: ^voter} | _] = builder.errors
    end
  end

  describe "voting_procedures round trip through TxBody" do
    test "builder votes encode + decode back to the same procedures" do
      voter = Gov.drep_voter(@drep_hash)
      action = Gov.gov_action_id(@action_tx, 0)
      votes = new_tx() |> vote(voter, action, :yes) |> Map.fetch!(:votes)

      body = %TxBody{
        inputs: [%OutputReference{transaction_id: @action_tx, output_index: 0}],
        outputs: [Output.new(Address.from_bech32(sample_address()), Asset.from_lovelace(2_000_000))],
        fee: Asset.from_lovelace(170_000),
        voting_procedures: votes
      }

      decoded = body |> TxBody.to_cbor() |> TxBody.decode()

      assert decoded.voting_procedures == votes
    end
  end
end
