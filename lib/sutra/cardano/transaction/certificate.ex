defmodule Sutra.Cardano.Transaction.Certificate do
  @moduledoc """
    Cardano Transaction Certificate
  """

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Certificate.PoolRegistration
  alias Sutra.Cardano.Transaction.Certificate.PoolRetirement
  alias Sutra.Cardano.Transaction.Certificate.Drep
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Common.PoolRelay
  alias Sutra.Cardano.Transaction.Certificate.StakeRegistration
  alias Sutra.Cardano.Address.Credential

  import Sutra.Data.Cbor, only: [extract_value!: 1]
  import Sutra.Utils, only: [maybe: 3]

  @type drep() :: %{
          drep_type: Address.credential_type() | nil,
          drep_value: String.t()
        }

  use TypedStruct

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
    field(:margin, :integer, enforce: true)
    field(:reward_account, :string, enforce: true)
    field(:owners, [:string], enforce: true)
    field(:relays, [PoolRelay.t()], enforce: true)
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

  typedstruct(module: Drep) do
    field(:drep_type, Address.credential_type() | nil | pos_integer())
    field(:drep_value, :string)
  end

  def decode([0, stake_credential]) do
    %StakeRegistration{stake_credential: parse_credential(stake_credential)}
  end

  def decode([1, stake_credential]) do
    %StakeDeRegistration{stake_credential: parse_credential(stake_credential)}
  end

  def decode([2, stake_cred, pool_key]) do
    %StakeDelegation{
      stake_credential: parse_credential(stake_cred),
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
      pledge: Asset.lovelace_of(pledge),
      cost: Asset.lovelace_of(cost),
      margin: n / d,
      reward_account: extract_value!(reward_accont),
      owners: Enum.map(owners, &extract_value!/1),
      relays: Enum.map(relays, &PoolRelay.decode/1),
      metadata: maybe(pool_metadata, nil, fn [u, h] -> %{url: u, hash: h} end)
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
      stake_credential: parse_credential(stake_credential),
      coin: Asset.lovelace_of(coin)
    }
  end

  def decode([9, stake_credential, drep]) do
    %VoteDelegCert{
      stake_credential: parse_credential(stake_credential),
      drep: decode_drep(drep)
    }
  end

  def decode([10, stake_cred, pool_key_hash, drep]) do
    %StakeVoteDelegCert{
      stake_credential: parse_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key_hash),
      drep: decode_drep(drep)
    }
  end

  def decode([11, stake_cred, pool_key_hash, coin]) do
    %StakeRegDelegCert{
      stake_credential: parse_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key_hash),
      deposit: Asset.lovelace_of(coin)
    }
  end

  def decode([13, stake_cred, pool_key_hash, drep, coin]) do
    %StakeVoteRegDelegCert{
      stake_credential: parse_credential(stake_cred),
      pool_keyhash: extract_value!(pool_key_hash),
      drep: decode_drep(drep),
      deposit: Asset.lovelace_of(coin)
    }
  end

  def decode([14, cold_cred, hot_cred]) do
    %AuthCommitteeHotCert{
      committee_cold_credential: parse_credential(cold_cred),
      committee_hot_credential: parse_credential(hot_cred)
    }
  end

  def decode([12, stake_cred, drep, coin]) do
    %VoteRegDelegCert{
      stake_credential: parse_credential(stake_cred),
      drep: decode_drep(drep),
      deposit: Asset.lovelace_of(coin)
    }
  end

  def decode([16, drep_cred, coin, anchor]) do
    %RegDrepCert{
      drep_credential: parse_credential(drep_cred),
      deposit: Asset.lovelace_of(coin),
      anchor: maybe(anchor, nil, fn [u, h] -> %{url: u, hash: h} end)
    }
  end

  def decode([17, drep_cred, coin]) do
    %UnRegDrepCert{
      drep_credential: parse_credential(drep_cred),
      deposit: Asset.lovelace_of(coin)
    }
  end

  def decode([18, drep_cred, anchor]) do
    %UpdateDrepCert{
      drep_credential: parse_credential(drep_cred),
      anchor: maybe(anchor, nil, fn [u, h] -> %{url: u, hash: h} end)
    }
  end

  defp parse_credential([cred_type, %CBOR.Tag{value: stake_credential}]) do
    credential_type = if cred_type == 0, do: :vkey, else: :script
    %Credential{credential_type: credential_type, hash: stake_credential}
  end

  def decode_drep([0, v]), do: %Drep{drep_type: :vkey, drep_value: extract_value!(v)}
  def decode_drep([1, v]), do: %Drep{drep_type: :script, drep_value: extract_value!(v)}
  def decode_drep([n | _]) when is_integer(n), do: %Drep{drep_type: n}
  def decode_drep(_), do: nil
end
