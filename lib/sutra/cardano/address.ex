defmodule Sutra.Cardano.Address do
  @moduledoc """
   Cardano Address
  """

  use TypedStruct

  alias Sutra.Cardano.Script
  alias __MODULE__, as: Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Address.Parser
  alias Sutra.Cardano.Address.Pointer
  alias Sutra.Data
  alias Sutra.Data.Cbor
  alias Sutra.Data.Plutus.Constr

  import Sutra.Utils, only: [maybe: 3]

  @type credential_type :: :vkey | :script
  @type address_type :: :shelley | :reward | :byron
  @type stake_credential :: Credential.t() | Pointer.t() | nil
  @type network :: :mainnet | :testnet
  @type bech_32() :: binary()

  @valid_network [:mainnet, :preprod, :preview, :custom, :testnet]

  typedstruct module: Credential do
    @moduledoc """
      Address Credential
    """
    field(:credential_type, Address.credential_type(), enforce: true)
    field(:hash, String.t(), enforce: true)
  end

  typedstruct module: Pointer do
    @moduledoc """
      Address Pointer
    """
    field(:slot, pos_integer(), enforce: true)
    field(:tx_index, pos_integer(), enforce: true)
    field(:cert_index, pos_integer(), enforce: true)
  end

  typedstruct do
    field(:network, Address.network(), enforce: true)
    field(:address_type, address_type(), enforce: true)
    field(:payment_credential, Credential.t())
    field(:stake_credential, stake_credential())
  end

  @doc """
    Return an address from a Bech32

      ## Example
        iex> from_bech32("addr1vx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzers66hrl8")
        {:ok, %Address{network: :mainnet, address_type: :shelley, ..}}

        iex> from_bech32("stake178phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtcccycj5")
        {:ok, %Address{network: :mainnet, address_type: :reward, ..}}

  """
  def from_bech32(bech32_addr) do
    case Bech32.decode(bech32_addr) do
      {:ok, _hmr, bytes} -> Parser.decode(bytes)
      _ -> {:error, "Invalid Bech32 address"}
    end
  end

  @doc """
    Convert an address to a Bech32

    ## Example
    iex> to_bech32(%Address{network: :mainnet, address_type: :shelley})
    {:ok, "addr1vx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzers66hrl8"}

    iex> to_bech32(%Address{network: :mainnet, address_type: :reward})
    {:ok, "stake178phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtcccycj5"}

  """
  def to_bech32(%Address{} = address) do
    hrp_prefix =
      case address.address_type do
        :shelley -> "addr"
        :reward -> "stake"
        _ -> ""
      end

    is_padded =
      case address.stake_credential do
        %Pointer{} -> false
        _ -> true
      end

    hrp =
      if address.network == :mainnet do
        hrp_prefix
      else
        hrp_prefix <> "_test"
      end

    data = Parser.encode(address) |> Bech32.convertbits(8, 5, is_padded)
    Bech32.encode_from_5bit(hrp, data)
  end

  @spec from_plutus(binary() | Sutra.Data.Plutus.t()) ::
          Address.t() | {:error, String.t()} | {:error, any()}
  def from_plutus(data) when is_binary(data) do
    case Data.decode(data) do
      {:ok, decoded} -> from_plutus(decoded)
      {:error, reason} -> {:error, reason}
    end
  end

  def from_plutus(%Constr{index: 0, fields: [pay_cred, stake_cred]}) do
    {:ok,
     %Address{
       network: nil,
       address_type: :shelley,
       payment_credential: fetch_payment_credential(pay_cred),
       stake_credential: fetch_stake_credential(stake_cred)
     }}
  end

  defp fetch_payment_credential(%Constr{index: indx, fields: [vkey_hash]}) do
    credential_type = if indx == 0, do: :vkey, else: :script
    %Credential{credential_type: credential_type, hash: Cbor.extract_value!(vkey_hash)}
  end

  defp fetch_stake_credential(%Constr{index: 1}), do: nil

  defp fetch_stake_credential(%Constr{
         fields: [%Constr{fields: [slot, tx_index, cert_index], index: 1}]
       }),
       do: %Pointer{slot: slot, tx_index: tx_index, cert_index: cert_index}

  defp fetch_stake_credential(%Constr{
         fields: [
           %Constr{
             fields: [%Constr{fields: [stake_cred_hash], index: indx}]
           }
         ]
       }) do
    credential_type = if indx == 0, do: :vkey, else: :script
    %Credential{credential_type: credential_type, hash: Cbor.extract_value!(stake_cred_hash)}
  end

  @spec to_plutus(Address.t()) :: Sutra.Data.Plutus.t()
  def to_plutus(%Address{} = addr) do
    payment_credential =
      case addr.payment_credential do
        %Credential{credential_type: :vkey, hash: hash} ->
          %Constr{index: 0, fields: [Cbor.as_byte(hash)]}

        %Credential{credential_type: :script, hash: hash} ->
          %Constr{index: 1, fields: [Cbor.as_byte(hash)]}
      end

    stake_credential =
      case addr.stake_credential do
        %Pointer{slot: slot, tx_index: tx_index, cert_index: cert_index} ->
          %Constr{
            index: 0,
            fields: [
              %Constr{
                index: 1,
                fields: [slot, tx_index, cert_index]
              }
            ]
          }

        %Credential{credential_type: :vkey, hash: hash} ->
          %Constr{
            index: 0,
            fields: [
              %Constr{
                index: 0,
                fields: [
                  %Constr{
                    index: 0,
                    fields: [Cbor.as_byte(hash)]
                  }
                ]
              }
            ]
          }

        %Credential{credential_type: :script, hash: hash} ->
          %Constr{
            index: 0,
            fields: [
              %Constr{
                index: 0,
                fields: [
                  %Constr{
                    index: 1,
                    fields: [Cbor.as_byte(hash)]
                  }
                ]
              }
            ]
          }

        nil ->
          %Constr{index: 1, fields: []}
      end

    %Constr{
      index: 0,
      fields: [payment_credential, stake_credential]
    }
  end

  def to_cbor(%Address{} = addr) do
    %CBOR.Tag{tag: :bytes, value: Parser.encode(addr)}
  end

  def from_script(_script, network)
      when network not in [:mainnet, :testnet, :preview, :preprod],
      do: {:error, "Invalid Network ID"}

  def from_script(%Script{} = script, network) do
    script_payment_key = Script.hash_script(script)
    from_script(script_payment_key, network)
  end

  def from_script(script_hash, network) when is_binary(script_hash) do
    %__MODULE__{
      network: network,
      address_type: :shelley,
      payment_credential: %Credential{
        credential_type: :script,
        hash: script_hash
      },
      stake_credential: nil
    }
  end

  def from_verification_key(vkey, stake_key \\ nil, network)
      when is_binary(vkey) and network in @valid_network do
    stake_key_cred =
      maybe(stake_key, nil, fn hash ->
        %Credential{credential_type: :vkey, hash: hash}
      end)

    %__MODULE__{
      network: network,
      address_type: :shelley,
      payment_credential: %Credential{
        credential_type: :vkey,
        hash: vkey
      },
      stake_credential: stake_key_cred
    }
  end

  def script_address?(%__MODULE__{
        payment_credential: %Credential{credential_type: credential_type}
      }),
      do: credential_type == :script

  def vkey_address?(%__MODULE__{
        payment_credential: %Credential{credential_type: credential_type}
      }),
      do: credential_type == :vkey
end
