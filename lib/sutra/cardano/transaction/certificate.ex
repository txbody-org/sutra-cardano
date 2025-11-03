defmodule Sutra.Cardano.Transaction.Certificate do
  @moduledoc """
    Cardano Transaction Certificate
  """

  use TypedStruct

  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Common.PoolRelay
  alias Sutra.Cardano.Transaction.Certificate.PoolRegistration
  alias Sutra.Cardano.Transaction.Certificate.PoolRetirement
  alias Sutra.Cardano.Transaction.Certificate.StakeRegistration
  alias Sutra.Data.Cbor

  import Sutra.Data.Cbor, only: [extract_value!: 1]
  import Sutra.Utils, only: [maybe: 3]

  ## (0, stake_credential) -- will be deprecated in future era
  typedstruct(module: StakeRegistration) do
    field(:stake_credential, Credential.t(), enforce: true)
  end

  ## (1, stake_credential) -- will be deprecated in future era
  typedstruct(module: StakeDeRegistration) do
    field(:stake_credential, Credential.t(), enforce: true)
  end

  ## (2, stake_credential, pool_keyhash)
  typedstruct(module: StakeDelegation) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:pool_keyhash, :string, enforce: true)
  end

  ## (3, pool_params)
  typedstruct(module: PoolRegistration) do
    field(:pool_key_hash, :string, enforce: true)
    field(:vrf_key_hash, :string, enforce: true)
    field(:pledge, :integer, enforce: true)
    field(:cost, :integer, enforce: true)
    field(:margin, :float, enforce: true)
    field(:margin_ratio, {pos_integer(), pos_integer()}, enforce: true)
    field(:reward_account, :string, enforce: true)
    field(:owners, [:string], enforce: true)
    field(:relays, [__MODULE__.PoolRelay.t()], enforce: true)
    field(:metadata, %{url: :string, hash: :string})
  end

  ## (4, pool_keyhash, epoch_no)
  typedstruct(module: PoolRetirement) do
    field(:pool_keyhash, :string, enforce: true)
    field(:epoch_no, :integer, enforce: true)
  end

  ## (7, stake_credential, coin)
  typedstruct(module: RegisterCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:coin, :integer, enforce: true)
  end

  ## (8, stake_credential, coin)
  typedstruct(module: UnRegisterCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:coin, :integer, enforce: true)
  end

  ## vote_deleg_cert   (9, stake_credential, drep)
  typedstruct(module: VoteDelegCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:drep, Drep.t(), enforce: true)
  end

  ## (10, stake_credential, pool_keyhash, drep)
  typedstruct(module: StakeVoteDelegCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:pool_keyhash, :string, enforce: true)
    field(:drep, Drep.t(), enforce: true)
  end

  ## (11, stake_credential, pool_keyhash, coin)
  typedstruct(module: StakeRegDelegCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:pool_keyhash, :string, enforce: true)
    field(:deposit, Asset.t(), enforce: true)
  end

  ## (12, stake_credential, drep, coin)
  typedstruct(module: VoteRegDelegCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:drep, :string, enforce: true)
    field(:deposit, :integer, enforce: true)
  end

  ## (13, stake_credential, pool_keyhash, drep, coin)
  typedstruct(module: StakeVoteRegDelegCert) do
    field(:stake_credential, Credential.t(), enforce: true)
    field(:pool_keyhash, :string, enforce: true)
    field(:drep, :string, enforce: true)
    field(:deposit, Asset.t(), enforce: true)
  end

  ## (14, committee_cold_credential, committee_hot_credential)
  typedstruct(module: AuthCommitteeHotCert) do
    field(:committee_cold_credential, Credential.t(), enforce: true)
    field(:committee_hot_credential, Credential.t(), enforce: true)
  end

  ## (15, committee_cold_credential, anchor / nil)
  typedstruct(module: ResignCommitteeColdCert) do
    field(:committee_cold_credential, Credential.t(), enforce: true)
    field(:anchor, :string)
  end

  ## (16, drep_credential, coin, anchor / nil)
  typedstruct(module: RegDrepCert) do
    field(:drep_credential, Credential.t(), enforce: true)
    field(:deposit, Asset.t(), enforce: true)
    field(:anchor, %{url: :string, hash: :string})
  end

  ## (17, drep_credential, coin)
  typedstruct(module: UnRegDrepCert) do
    field(:drep_credential, Credential.t(), enforce: true)
    field(:deposit, Asset.t(), enforce: true)
  end

  ## (18, drep_credential, anchor / nil)
  typedstruct(module: UpdateDrepCert) do
    field(:drep_credential, Credential.t(), enforce: true)
    field(:anchor, %{url: :string, hash: :string})
  end

  @doc """
    decode CBOR data to Certificate
  """
  def decode([0, stake_credential]) do
    %StakeRegistration{stake_credential: decode_credential(stake_credential)}
  end

  def decode([1, stake_credential]) do
    %StakeDeRegistration{stake_credential: decode_credential(stake_credential)}
  end

  def decode([2, stake_cred, pool_key]) do
    %StakeDelegation{
      stake_credential: decode_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key)
    }
  end

  def decode([
        3,
        pool_key,
        vrf,
        pledge,
        cost,
        %CBOR.Tag{value: [n, d]},
        reward_accont,
        owners,
        relays,
        pool_metadata
      ]) do
    %PoolRegistration{
      pool_key_hash: extract_value!(pool_key),
      vrf_key_hash: extract_value!(vrf),
      pledge: Asset.from_lovelace(pledge),
      cost: Asset.from_lovelace(cost),
      margin: n / d,
      margin_ratio: {n, d},
      reward_account: extract_value!(reward_accont),
      owners: Enum.map(extract_value!(owners), &extract_value!/1),
      relays: Enum.map(extract_value!(relays), &PoolRelay.decode/1),
      metadata:
        maybe(pool_metadata, nil, fn [u, h] ->
          %{url: extract_value!(u), hash: extract_value!(h)}
        end)
    }
  end

  def decode([4, %CBOR.Tag{value: pool_keyhash}, epoch_no]) do
    %PoolRetirement{pool_keyhash: pool_keyhash, epoch_no: epoch_no}
  end

  def decode([7, [cred_type, %CBOR.Tag{value: stake_credential}], coin]) do
    credential_type = if cred_type == 0, do: :vkey, else: :script

    %RegisterCert{
      stake_credential: %Credential{credential_type: credential_type, hash: stake_credential},
      coin: coin
    }
  end

  def decode([8, stake_credential, coin]) do
    %UnRegisterCert{
      stake_credential: decode_credential(stake_credential),
      coin: Asset.from_lovelace(coin)
    }
  end

  def decode([9, stake_credential, drep]) do
    %VoteDelegCert{
      stake_credential: decode_credential(stake_credential),
      drep: Drep.from_cbor(drep)
    }
  end

  def decode([10, stake_cred, pool_key_hash, drep]) do
    %StakeVoteDelegCert{
      stake_credential: decode_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key_hash),
      drep: Drep.from_cbor(drep)
    }
  end

  def decode([11, stake_cred, pool_key_hash, coin]) do
    %StakeRegDelegCert{
      stake_credential: decode_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key_hash),
      deposit: Asset.from_lovelace(coin)
    }
  end

  def decode([13, stake_cred, pool_key_hash, drep, coin]) do
    %StakeVoteRegDelegCert{
      stake_credential: decode_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key_hash),
      drep: Drep.from_cbor(drep),
      deposit: Asset.from_lovelace(coin)
    }
  end

  def decode([14, cold_cred, hot_cred]) do
    %AuthCommitteeHotCert{
      committee_cold_credential: decode_credential(cold_cred),
      committee_hot_credential: decode_credential(hot_cred)
    }
  end

  def decode([12, stake_cred, drep, coin]) do
    %VoteRegDelegCert{
      stake_credential: decode_credential(stake_cred),
      drep: Drep.from_cbor(drep),
      deposit: Asset.from_lovelace(coin)
    }
  end

  def decode([16, drep_cred, coin, anchor]) do
    %RegDrepCert{
      drep_credential: decode_credential(drep_cred),
      deposit: Asset.from_lovelace(coin),
      anchor: maybe(anchor, nil, fn [u, h] -> %{url: u, hash: h} end)
    }
  end

  def decode([17, drep_cred, coin]) do
    %UnRegDrepCert{
      drep_credential: decode_credential(drep_cred),
      deposit: Asset.from_lovelace(coin)
    }
  end

  def decode([18, drep_cred, anchor]) do
    %UpdateDrepCert{
      drep_credential: decode_credential(drep_cred),
      anchor: maybe(anchor, nil, fn [u, h] -> %{url: u, hash: h} end)
    }
  end

  defp decode_credential([cred_type, %CBOR.Tag{} = stake_credential]) do
    credential_type = if cred_type == 0, do: :vkey, else: :script
    %Credential{credential_type: credential_type, hash: extract_value!(stake_credential)}
  end

  defp encode_credential(%Credential{} = cred) do
    credential_type = if cred.credential_type == :vkey, do: 0, else: 1
    [credential_type, Cbor.as_byte(cred.hash)]
  end

  @doc """
    encode Certificate to CBOR data

  """

  def to_cbor(%StakeRegistration{} = stk_reg) do
    [0, encode_credential(stk_reg.stake_credential)]
  end

  def to_cbor(%StakeDeRegistration{} = stk_dereg) do
    [1, encode_credential(stk_dereg.stake_credential)]
  end

  def to_cbor(%StakeDelegation{} = stk_deleg) do
    [2, encode_credential(stk_deleg.stake_credential), Cbor.as_byte(stk_deleg.pool_keyhash)]
  end

  def to_cbor(%PoolRegistration{} = pool_reg) do
    owners =
      pool_reg.owners
      |> Enum.map(&Cbor.as_byte/1)
      |> Cbor.as_set()

    [
      3,
      Cbor.as_byte(pool_reg.pool_key_hash),
      Cbor.as_byte(pool_reg.vrf_key_hash),
      Asset.to_cbor(pool_reg.pledge),
      Asset.to_cbor(pool_reg.cost),
      Cbor.as_unit_interval(pool_reg.margin_ratio),
      Cbor.as_byte(pool_reg.reward_account),
      owners,
      Enum.map(pool_reg.relays, &PoolRelay.encode/1),
      maybe(pool_reg.metadata, nil, fn %{url: u, hash: h} ->
        [u, Cbor.as_byte(h)]
      end)
    ]
  end

  def to_cbor(%PoolRetirement{} = pool_ret) do
    [4, Cbor.as_byte(pool_ret.pool_keyhash), pool_ret.epoch_no]
  end

  def to_cbor(%RegisterCert{} = reg_cert) do
    [7, encode_credential(reg_cert.stake_credential), Asset.to_cbor(reg_cert.coin)]
  end

  def to_cbor(%UnRegisterCert{} = unreg_cert) do
    [8, encode_credential(unreg_cert.stake_credential), Asset.to_cbor(unreg_cert.coin)]
  end

  def to_cbor(%VoteDelegCert{} = vote_deleg_cert) do
    [9, encode_credential(vote_deleg_cert.stake_credential), Drep.to_cbor(vote_deleg_cert.drep)]
  end

  def to_cbor(%StakeVoteDelegCert{} = stake_vote_deleg_cert) do
    [
      10,
      encode_credential(stake_vote_deleg_cert.stake_credential),
      Cbor.as_byte(stake_vote_deleg_cert.pool_keyhash),
      Drep.to_cbor(stake_vote_deleg_cert.drep)
    ]
  end

  def to_cbor(%StakeRegDelegCert{} = stake_reg_deleg_cert) do
    [
      11,
      encode_credential(stake_reg_deleg_cert.stake_credential),
      Cbor.as_byte(stake_reg_deleg_cert.pool_keyhash),
      Asset.to_cbor(stake_reg_deleg_cert.deposit)
    ]
  end

  def to_cbor(%StakeVoteRegDelegCert{} = stake_vote_reg_deleg_cert) do
    [
      13,
      encode_credential(stake_vote_reg_deleg_cert.stake_credential),
      Cbor.as_byte(stake_vote_reg_deleg_cert.pool_keyhash),
      Drep.to_cbor(stake_vote_reg_deleg_cert.drep),
      Asset.to_cbor(stake_vote_reg_deleg_cert.deposit)
    ]
  end

  def to_cbor(%AuthCommitteeHotCert{} = auth_committee_hot_cert) do
    [
      14,
      encode_credential(auth_committee_hot_cert.committee_cold_credential),
      encode_credential(auth_committee_hot_cert.committee_hot_credential)
    ]
  end

  def to_cbor(%VoteRegDelegCert{} = vote_reg_deleg_cert) do
    [
      12,
      encode_credential(vote_reg_deleg_cert.stake_credential),
      Drep.to_cbor(vote_reg_deleg_cert.drep),
      Asset.to_cbor(vote_reg_deleg_cert.deposit)
    ]
  end

  def to_cbor(%RegDrepCert{} = reg_drep_cert) do
    [
      16,
      encode_credential(reg_drep_cert.drep_credential),
      Asset.to_cbor(reg_drep_cert.deposit),
      maybe(reg_drep_cert.anchor, nil, fn %{url: u, hash: h} -> [u, Cbor.as_byte(h)] end)
    ]
  end

  def to_cbor(%UnRegDrepCert{} = unreg_drep_cert) do
    [
      17,
      encode_credential(unreg_drep_cert.drep_credential),
      Asset.to_cbor(unreg_drep_cert.deposit)
    ]
  end

  def to_cbor(%UpdateDrepCert{} = update_drep_cert) do
    [
      18,
      encode_credential(update_drep_cert.drep_credential),
      maybe(update_drep_cert.anchor, nil, fn %{url: u, hash: h} -> [u, Cbor.as_byte(h)] end)
    ]
  end
end
