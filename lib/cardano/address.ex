defmodule Cardano.Address do
  @moduledoc """
   Cardano Address
  """

  defmodule Credential do
    defstruct [
      :credential_type,
      :hash
    ]
  end

  defmodule Pointer do
    defstruct [
      :slot,
      :tx_index,
      :cert_index
    ]
  end

  defstruct [
    :network,
    :address_type,
    :payment_credential,
    :stake_credential
  ]

  alias Cardano.Address
  alias Cardano.Address.Parser

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
