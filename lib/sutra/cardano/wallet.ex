defmodule Sutra.Cardano.Wallet do
  @moduledoc """
    Wallet Helper function
  """

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Crypto.Key
  alias Sutra.Crypto.Key.RootKey

  import Sutra.Utils, only: [maybe: 2, when_ok: 2]

  @type t() :: %__MODULE__{
          key: Key.key_type()
        }

  defstruct [:key]

  def from_mnemonic(mnemonic) when is_binary(mnemonic) do
    %__MODULE__{
      key: Key.root_key_from_mnemonic(mnemonic)
    }
  end

  def from_bech32(bech_32_str) do
    case Bech32.decode(bech_32_str) do
      {:ok, hrp, data} -> from_bech32(hrp, data)
      _ -> {:error, "Invalid Bech32 Key"}
    end
  end

  def from_bech32("ed25519_sk", data) when is_binary(data),
    do: %__MODULE__{key: %Key.Ed25519key{private_key: data}}

  def address(mod, network, acct_indx \\ 0, addr_indx \\ 0)

  def address(%__MODULE__{key: %RootKey{} = key}, network, acct_indx, addr_indx) do
    Key.derive_child(key, acct_indx, addr_indx)
    |> when_ok(fn k ->
      address(%__MODULE__{key: k}, network)
    end)

    with {:ok, %Key.ExtendedKey{} = extended_key} <-
           Key.derive_child(key, acct_indx, addr_indx) do
      address(%__MODULE__{key: extended_key}, acct_indx, addr_indx)
    end
  end

  def address(
        %__MODULE__{key: %Key.ExtendedKey{} = extended_key},
        network,
        _acct_indx,
        __addr_indx
      ) do
    payment_key_hash =
      Key.public_key(extended_key, :payment_key) |> maybe(&Blake2b.blake2b_224/1)

    stake_key_hash = Key.public_key(extended_key, :stake_key) |> maybe(&Blake2b.blake2b_224/1)

    {:ok, Address.from_verification_key(payment_key_hash, stake_key_hash, network)}
  end
end
