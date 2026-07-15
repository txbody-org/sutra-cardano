defmodule Sutra.Cardano.GovTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Gov
<<<<<<< HEAD
  alias Sutra.Cardano.Gov.{Voter, VotingProcedure}
  alias Sutra.Cardano.Transaction.OutputReference
=======
  alias Sutra.Cardano.Gov.{GovActionId, Voter, VotingProcedure}
>>>>>>> dd915fc (feat: enhance governance module with voter and voting procedure structures and tests)

  @tx_id "bcaeed39733e00db82a5492d5b4791de8dc7e8b4859dafe89ec3915304bd4f4b"
  @key_hash "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
  @script_hash "a687dcc24e00dd3caafbeb5e68f97ca8ef269cb6fe971345eb951756"

  describe "Voter cbor round trip" do
    for {voter_type, credential_type, tag} <- [
          {:committee_hot, :vkey, 0},
          {:committee_hot, :script, 1},
          {:drep, :vkey, 2},
          {:drep, :script, 3},
          {:stake_pool, :vkey, 4}
        ] do
      test "#{voter_type}/#{credential_type} encodes with tag #{tag} and decodes back" do
        hash = if unquote(credential_type) == :vkey, do: @key_hash, else: @script_hash

        voter = %Voter{
          voter_type: unquote(voter_type),
          credential: %Credential{credential_type: unquote(credential_type), hash: hash}
        }

        assert [unquote(tag), _] = Gov.voter_to_cbor(voter)
        assert voter |> Gov.voter_to_cbor() |> Gov.decode_voter!() == voter
      end
    end
  end

  describe "vote encode/decode" do
    test "round trips :no, :yes, :abstain" do
      for {vote, code} <- [no: 0, yes: 1, abstain: 2] do
        assert Gov.encode_vote(vote) == code
        assert Gov.decode_vote!(code) == vote
      end
    end
  end

  describe "voting_procedures round trip" do
    test "encodes and decodes a full voting_procedures map, with and without anchor" do
      voting_procedures = %{
        %Voter{
          voter_type: :drep,
          credential: %Credential{credential_type: :vkey, hash: @key_hash}
        } => %{
<<<<<<< HEAD
          %OutputReference{transaction_id: @tx_id, output_index: 0} => %VotingProcedure{
=======
          %GovActionId{transaction_id: @tx_id, gov_action_index: 0} => %VotingProcedure{
>>>>>>> dd915fc (feat: enhance governance module with voter and voting procedure structures and tests)
            vote: :yes,
            anchor: nil
          }
        },
        %Voter{
          voter_type: :stake_pool,
          credential: %Credential{credential_type: :vkey, hash: @key_hash}
        } => %{
<<<<<<< HEAD
          %OutputReference{transaction_id: @tx_id, output_index: 1} => %VotingProcedure{
=======
          %GovActionId{transaction_id: @tx_id, gov_action_index: 1} => %VotingProcedure{
>>>>>>> dd915fc (feat: enhance governance module with voter and voting procedure structures and tests)
            vote: :abstain,
            anchor: %{url: "https://example.com", hash: @script_hash}
          }
        }
      }

      assert voting_procedures
             |> Gov.encode_voting_procedures()
             |> Gov.decode_voting_procedures() == voting_procedures
    end

    test "decode_voting_procedures/1 returns nil when not a map" do
      assert Gov.decode_voting_procedures(nil) == nil
    end
  end
end
