defmodule Sutra.Cardano.Address do
  @moduledoc """
   Cardano Address
  """

  use TypedStruct

  alias __MODULE__, as: Address
  alias Sutra.Cardano.Address.Parser

  @type credential_type :: :vkey | :script
  @type address_type :: :shelley | :reward | :byron
  @type stake_credential :: Credential.t() | Pointer.t() | nil
  @type network :: :mainnet | :testnet

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
    field(:slot, Integer.t(), enforce: true)
    field(:tx_index, Integer.t(), enforce: true)
    field(:cert_index, Integer.t(), enforce: true)
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

    hrp =
      if address.network == :mainnet do
        hrp_prefix
      else
        hrp_prefix <> "_test"
      end

    data = Parser.encode(address) |> Base.decode16!(case: :lower)

    Bech32.encode(hrp, data)
  end
end
