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

  alias Cardano.Address.Parser

  def from_bech32(bech32_addr) do
    case Bech32.decode(bech32_addr) do
      {:ok, _hmr, bytes} -> Parser.decode(bytes)
      _ -> {:error, "Invalid Bech32 address"}
    end
  end
end
