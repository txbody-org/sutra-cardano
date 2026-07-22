defmodule Sutra.Cardano.Gov.GovAction do
  @moduledoc """
    Governance actions (the `gov_action` CDDL group) that can be submitted as
    part of a `proposal_procedure`.

    Dijkstra/Conway defines seven actions. Six are modelled here as typed
    structs with `decode/1` and `to_cbor/1`:

      * `HardForkInitiation` (1)
      * `TreasuryWithdrawals` (2)
      * `NoConfidence` (3)
      * `UpdateCommittee` (4)
      * `NewConstitution` (5)
      * `InfoAction` (6)

    `parameter_change_action` (0) is not fully modelled yet: its
    `protocol_param_update` payload is retained raw so proposals still decode
    and round-trip, but there is no typed API or builder helper for it.
  """

  use TypedStruct

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Data.Cbor

  import Sutra.Data.Cbor, only: [extract_value!: 1]

  ## (0, gov_action_id/nil, protocol_param_update, guardrails_script_hash/nil)
  ## protocol_param_update is retained raw (undecoded) for now.
  typedstruct(module: ParameterChange) do
    field(:gov_action_id, OutputReference.t())
    field(:protocol_param_update, any(), enforce: true)
    field(:guardrails_script_hash, String.t())
  end

  ## (1, gov_action_id/nil, protocol_version)
  typedstruct(module: HardForkInitiation) do
    field(:gov_action_id, OutputReference.t())
    field(:protocol_version, {pos_integer(), non_neg_integer()}, enforce: true)
  end

  ## (2, {* reward_account => coin}, guardrails_script_hash/nil)
  typedstruct(module: TreasuryWithdrawals) do
    field(:withdrawals, %{String.t() => Asset.t()}, enforce: true)
    field(:guardrails_script_hash, String.t())
  end

  ## (3, gov_action_id/nil)
  typedstruct(module: NoConfidence) do
    field(:gov_action_id, OutputReference.t())
  end

  ## (4, gov_action_id/nil, set<cold_cred>, {* cold_cred => epoch}, unit_interval)
  typedstruct(module: UpdateCommittee) do
    field(:gov_action_id, OutputReference.t())
    field(:removed_members, [Credential.t()], default: [])
    field(:added_members, %{Credential.t() => integer()}, default: %{})
    field(:quorum, {pos_integer(), pos_integer()}, enforce: true)
  end

  ## (5, gov_action_id/nil, constitution)
  ## constitution = [anchor, guardrails_script_hash/nil]
  typedstruct(module: NewConstitution) do
    field(:gov_action_id, OutputReference.t())
    field(:anchor, %{url: String.t(), hash: String.t()}, enforce: true)
    field(:guardrails_script_hash, String.t())
  end

  ## (6) info_action — no on-chain effect
  defmodule InfoAction do
    @moduledoc "Info action (gov action 6): records intent, no on-chain effect."
    defstruct []
    @type t() :: %__MODULE__{}
  end

  # ---- Convenience constructors -------------------------------------------

  @doc "Builds a `HardForkInitiation` action for the given protocol version."
  def hard_fork(major, minor, gov_action_id \\ nil)
      when is_integer(major) and is_integer(minor),
      do: %HardForkInitiation{gov_action_id: gov_action_id, protocol_version: {major, minor}}

  @doc """
    Builds a `TreasuryWithdrawals` action. `withdrawals` is a map of
    reward-account hex => lovelace amount.
  """
  def treasury_withdrawals(withdrawals, opts \\ []) when is_map(withdrawals) do
    %TreasuryWithdrawals{
      withdrawals: Map.new(withdrawals, fn {acc, coin} -> {acc, Asset.from_lovelace(coin)} end),
      guardrails_script_hash: opts[:guardrails_script_hash]
    }
  end

  @doc "Builds a `NoConfidence` action."
  def no_confidence(gov_action_id \\ nil), do: %NoConfidence{gov_action_id: gov_action_id}

  @doc "Builds an `InfoAction`."
  def info, do: %InfoAction{}

  @doc """
    Builds a `NewConstitution` action from an anchor `%{url, hash}` and an
    optional guardrails script hash.
  """
  def new_constitution(anchor, opts \\ []) when is_map(anchor),
    do: %NewConstitution{
      gov_action_id: opts[:gov_action_id],
      anchor: anchor,
      guardrails_script_hash: opts[:guardrails_script_hash]
    }

  @doc """
    Builds an `UpdateCommittee` action. `added_members` is a map of committee
    cold `Credential` => expiry epoch, `removed_members` a list of cold
    `Credential`s, and `quorum` a `{numerator, denominator}` unit interval.
  """
  def update_committee(added_members, removed_members, {_n, _d} = quorum, opts \\ [])
      when is_map(added_members) and is_list(removed_members),
      do: %UpdateCommittee{
        gov_action_id: opts[:gov_action_id],
        added_members: added_members,
        removed_members: removed_members,
        quorum: quorum
      }

  # ---- decode --------------------------------------------------------------

  def decode([0, gov_action_id, protocol_param_update, guardrails]) do
    %ParameterChange{
      gov_action_id: decode_action_id(gov_action_id),
      protocol_param_update: protocol_param_update,
      guardrails_script_hash: decode_hash(guardrails)
    }
  end

  def decode([1, gov_action_id, [major, minor]]) do
    %HardForkInitiation{
      gov_action_id: decode_action_id(gov_action_id),
      protocol_version: {major, minor}
    }
  end

  def decode([2, withdrawals, guardrails]) do
    %TreasuryWithdrawals{
      withdrawals: decode_withdrawals(withdrawals),
      guardrails_script_hash: decode_hash(guardrails)
    }
  end

  def decode([3, gov_action_id]) do
    %NoConfidence{gov_action_id: decode_action_id(gov_action_id)}
  end

  def decode([4, gov_action_id, removed, added, quorum]) do
    %UpdateCommittee{
      gov_action_id: decode_action_id(gov_action_id),
      removed_members: removed |> extract_value!() |> Enum.map(&Address.credential_from_cbor/1),
      added_members: decode_committee_epochs(added),
      quorum: decode_unit_interval(quorum)
    }
  end

  def decode([5, gov_action_id, [anchor, guardrails]]) do
    %NewConstitution{
      gov_action_id: decode_action_id(gov_action_id),
      anchor: decode_anchor(anchor),
      guardrails_script_hash: decode_hash(guardrails)
    }
  end

  def decode([6]), do: %InfoAction{}

  # ---- encode --------------------------------------------------------------

  def to_cbor(%ParameterChange{} = action) do
    [
      0,
      encode_action_id(action.gov_action_id),
      action.protocol_param_update,
      encode_hash(action.guardrails_script_hash)
    ]
  end

  def to_cbor(%HardForkInitiation{protocol_version: {major, minor}} = action) do
    [1, encode_action_id(action.gov_action_id), [major, minor]]
  end

  def to_cbor(%TreasuryWithdrawals{} = action) do
    [
      2,
      encode_withdrawals(action.withdrawals),
      encode_hash(action.guardrails_script_hash)
    ]
  end

  def to_cbor(%NoConfidence{} = action) do
    [3, encode_action_id(action.gov_action_id)]
  end

  def to_cbor(%UpdateCommittee{} = action) do
    [
      4,
      encode_action_id(action.gov_action_id),
      action.removed_members |> Enum.map(&Address.credential_to_cbor/1) |> Cbor.as_set(),
      encode_committee_epochs(action.added_members),
      Cbor.as_unit_interval(action.quorum)
    ]
  end

  def to_cbor(%NewConstitution{} = action) do
    [
      5,
      encode_action_id(action.gov_action_id),
      [encode_anchor(action.anchor), encode_hash(action.guardrails_script_hash)]
    ]
  end

  def to_cbor(%InfoAction{}), do: [6]

  # ---- shared helpers ------------------------------------------------------

  defp decode_action_id(nil), do: nil
  defp decode_action_id(cbor), do: OutputReference.from_cbor(cbor)

  defp encode_action_id(nil), do: nil
  defp encode_action_id(%OutputReference{} = ref), do: OutputReference.to_cbor(ref)

  defp decode_hash(nil), do: nil
  defp decode_hash(hash), do: extract_value!(hash)

  defp encode_hash(nil), do: nil
  defp encode_hash(hash), do: Cbor.as_byte(hash)

  defp decode_withdrawals(withdrawals) when is_map(withdrawals) do
    Map.new(withdrawals, fn {k, v} -> {extract_value!(k), Asset.from_cbor(v)} end)
  end

  defp encode_withdrawals(withdrawals) do
    Map.new(withdrawals, fn {k, v} -> {Cbor.as_byte(k), Asset.to_cbor(v)} end)
  end

  defp decode_committee_epochs(added) when is_map(added) do
    Map.new(added, fn {cred, epoch} -> {Address.credential_from_cbor(cred), epoch} end)
  end

  defp encode_committee_epochs(added) do
    Map.new(added, fn {cred, epoch} -> {Address.credential_to_cbor(cred), epoch} end)
  end

  defp decode_unit_interval(%CBOR.Tag{tag: 30, value: [n, d]}), do: {n, d}

  defp decode_anchor([url, hash]), do: %{url: url, hash: extract_value!(hash)}

  defp encode_anchor(%{url: url, hash: hash}), do: [url, Cbor.as_byte(hash)]
end
