defmodule Sutra.Cardano.Gov do
  @moduledoc """
    Governance related actions
  """

  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Data.Cbor

  import Sutra.Data.Cbor, only: [extract_value!: 1]
  import Sutra.Utils, only: [maybe: 3]

  use TypedStruct

  typedstruct(module: CostModels) do
    field(:plutus_v1, [])
    field(:plutus_v2, [])
    field(:plutus_v3, [])
    field(:plutus_v4, [])
  end

  def encode_cost_models(%__MODULE__.CostModels{} = cost_models) do
    CBOR.encode(%{
      0 => cost_models.plutus_v1,
      1 => cost_models.plutus_v2,
      2 => cost_models.plutus_v3,
      3 => cost_models.plutus_v4
    })
  end

  typedstruct(module: Voter) do
    @moduledoc """
      A governance voter: either a constitutional committee hot credential,
      a DRep credential, or a stake pool key.
    """
    @type voter_type() :: :committee_hot | :drep | :stake_pool

    field(:voter_type, voter_type(), enforce: true)
    field(:credential, Credential.t(), enforce: true)
  end

  typedstruct(module: VotingProcedure) do
    @moduledoc """
      A single vote cast by a voter on a governance action, with an
      optional metadata anchor.
    """
    @type vote() :: :no | :yes | :abstain

    field(:vote, vote(), enforce: true)
    field(:anchor, %{url: String.t(), hash: String.t()})
  end

  @doc """
    Builds a DRep `Voter` from a `Credential`, a `Drep`, or a raw key-hash hex
    string (treated as a vkey credential).

    ## Examples

        iex> Gov.drep_voter(%Credential{credential_type: :vkey, hash: "abc..."})
        %Gov.Voter{voter_type: :drep, credential: %Credential{...}}

        iex> Gov.drep_voter(Drep.script_drep("script_hash_hex"))
        %Gov.Voter{voter_type: :drep, credential: %Credential{credential_type: :script, ...}}
  """
  def drep_voter(%Credential{} = credential),
    do: %Voter{voter_type: :drep, credential: credential}

  def drep_voter(%Drep{drep_type: :key_hash, drep_value: hash}),
    do: drep_voter(%Credential{credential_type: :vkey, hash: hash})

  def drep_voter(%Drep{drep_type: :script_hash, drep_value: hash}),
    do: drep_voter(%Credential{credential_type: :script, hash: hash})

  def drep_voter(key_hash) when is_binary(key_hash),
    do: drep_voter(%Credential{credential_type: :vkey, hash: key_hash})

  @doc """
    Builds a constitutional-committee `Voter` from the committee hot
    `Credential` (or a raw key-hash hex string, treated as a vkey credential).
  """
  def committee_voter(%Credential{} = credential),
    do: %Voter{voter_type: :committee_hot, credential: credential}

  def committee_voter(key_hash) when is_binary(key_hash),
    do: committee_voter(%Credential{credential_type: :vkey, hash: key_hash})

  @doc """
    Builds a stake-pool `Voter` from the pool key hash (hex string). Stake
    pools always vote with a key credential.
  """
  def stake_pool_voter(%Credential{hash: hash}), do: stake_pool_voter(hash)

  def stake_pool_voter(pool_key_hash) when is_binary(pool_key_hash),
    do: %Voter{
      voter_type: :stake_pool,
      credential: %Credential{credential_type: :vkey, hash: pool_key_hash}
    }

  @doc """
    Builds a governance action id from the proposing transaction id (hex) and
    the proposal's index within that transaction.

    A governance action is identified exactly like a UTxO — a transaction id
    plus an index — so it is represented as an `OutputReference`.

    ## Examples

        iex> Gov.gov_action_id("aabb...", 0)
        %Sutra.Cardano.Transaction.OutputReference{transaction_id: "aabb...", output_index: 0}
  """
  def gov_action_id(transaction_id, index)
      when is_binary(transaction_id) and is_integer(index),
      do: %OutputReference{transaction_id: transaction_id, output_index: index}

  def decode_voter!([0, key_hash]),
    do: %Voter{
      voter_type: :committee_hot,
      credential: %Credential{credential_type: :vkey, hash: extract_value!(key_hash)}
    }

  def decode_voter!([1, script_hash]),
    do: %Voter{
      voter_type: :committee_hot,
      credential: %Credential{credential_type: :script, hash: extract_value!(script_hash)}
    }

  def decode_voter!([2, key_hash]),
    do: %Voter{
      voter_type: :drep,
      credential: %Credential{credential_type: :vkey, hash: extract_value!(key_hash)}
    }

  def decode_voter!([3, script_hash]),
    do: %Voter{
      voter_type: :drep,
      credential: %Credential{credential_type: :script, hash: extract_value!(script_hash)}
    }

  def decode_voter!([4, key_hash]),
    do: %Voter{
      voter_type: :stake_pool,
      credential: %Credential{credential_type: :vkey, hash: extract_value!(key_hash)}
    }

  def voter_to_cbor(%Voter{
        voter_type: :committee_hot,
        credential: %Credential{credential_type: :vkey, hash: h}
      }),
      do: [0, Cbor.as_byte(h)]

  def voter_to_cbor(%Voter{
        voter_type: :committee_hot,
        credential: %Credential{credential_type: :script, hash: h}
      }),
      do: [1, Cbor.as_byte(h)]

  def voter_to_cbor(%Voter{
        voter_type: :drep,
        credential: %Credential{credential_type: :vkey, hash: h}
      }),
      do: [2, Cbor.as_byte(h)]

  def voter_to_cbor(%Voter{
        voter_type: :drep,
        credential: %Credential{credential_type: :script, hash: h}
      }),
      do: [3, Cbor.as_byte(h)]

  def voter_to_cbor(%Voter{voter_type: :stake_pool, credential: %Credential{hash: h}}),
    do: [4, Cbor.as_byte(h)]

  def decode_vote!(0), do: :no
  def decode_vote!(1), do: :yes
  def decode_vote!(2), do: :abstain

  def encode_vote(:no), do: 0
  def encode_vote(:yes), do: 1
  def encode_vote(:abstain), do: 2

  def decode_voting_procedure!([vote, anchor]),
    do: %VotingProcedure{
      vote: decode_vote!(vote),
      anchor: maybe(anchor, nil, fn [u, h] -> %{url: u, hash: extract_value!(h)} end)
    }

  def voting_procedure_to_cbor(%VotingProcedure{vote: vote, anchor: anchor}),
    do: [
      encode_vote(vote),
      maybe(anchor, nil, fn %{url: u, hash: h} -> [u, Cbor.as_byte(h)] end)
    ]

  @doc """
    Decode `voting_procedures = {+ voter => {+ gov_action_id => voting_procedure}}`
  """
  def decode_voting_procedures(voting_procedures) when is_map(voting_procedures) do
    for {voter, votes} <- voting_procedures, into: %{} do
      {decode_voter!(voter),
       for {gov_action_id, voting_procedure} <- votes, into: %{} do
         {OutputReference.from_cbor(gov_action_id), decode_voting_procedure!(voting_procedure)}
       end}
    end
  end

  def decode_voting_procedures(_), do: nil

  def encode_voting_procedures(voting_procedures) when is_map(voting_procedures) do
    for {voter, votes} <- voting_procedures, into: %{} do
      {voter_to_cbor(voter),
       for {gov_action_id, voting_procedure} <- votes, into: %{} do
         {OutputReference.to_cbor(gov_action_id), voting_procedure_to_cbor(voting_procedure)}
       end}
    end
  end
end
