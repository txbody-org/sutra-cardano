defmodule Sutra.Cardano.Common.Drep do
  @moduledoc """
    Drep
  """
  alias Sutra.Data.Cbor
  alias Sutra.Utils

  @type t() :: %__MODULE__{
          drep_type: :key_hash | :script_hash | :abstain | :no_confidence,
          drep_value: binary()
        }

  defstruct [:drep_type, :drep_value]

  # Credential Type (. . . . c c c c)	Semantic
  # ....0010	Key Hash
  # ....0011	Script Hash
  @credential_types %{
    2 => :key_hash,
    3 => :script_hash
  }

  import Sutra.Data.Cbor, only: [extract_value!: 1]

  @doc """
  Returns Drep from Bech32

    ## Example
      
      iex> from_bech32("drep1ytkuxg70g9dfvx7zemv2r4wpmdrudneemyfr6yw6ypzfalsmpgadu")
      {:ok, %Drep{drep_type: :key_hash, drep_value: "ed..."}}

      iex> from_bech32(invalid_drep_bech32)
      :error
  """

  def from_bech32(drep_bech32) do
    case Bech32.decode(drep_bech32) do
      {:ok, hrp, <<2::4, c::4, rest::bitstring>>} when hrp in ["drep", "drep_test"] ->
        {:ok,
         %__MODULE__{
           drep_type: @credential_types[c],
           drep_value: Base.encode16(rest, case: :lower)
         }}

      {:error, _} ->
        :error
    end
  end

  @doc """
  Returns Bech32 address for drep

      ## Example
      
        iex> to_bech32(%Drep{}, :mainnet)
        iex> "drep1ytkuxg70g9dfvx7zemv2r4wpmdrudneemyfr6yw6ypzfalsmpgadu"
  """
  def to_bech32(%__MODULE__{} = drep, network)
      when drep.drep_type in [:script_hash, :key_hash] do
    bytes = Utils.ok_or(Base.decode16(drep.drep_value, case: :mixed), drep.drep_value)
    credential_type = if drep.drep_type == :script_hash, do: 3, else: 2

    hrp =
      if network == :mainnet, do: "drep", else: "drep_test"

    Bech32.encode(hrp, <<2::4, credential_type::4, bytes::bitstring>>)
  end

  def key_hash_drep(value) when is_binary(value),
    do: %__MODULE__{
      drep_type: :key_hash,
      drep_value: value
    }

  def script_drep(value) when is_binary(value),
    do: %__MODULE__{
      drep_type: :script_hash,
      drep_value: value
    }

  def abstain, do: %__MODULE__{drep_type: :abstain}
  def no_confidence, do: %__MODULE__{drep_type: :no_confidence}

  def from_cbor([0, v]), do: key_hash_drep(extract_value!(v))
  def from_cbor([1, v]), do: script_drep(extract_value!(v))
  def from_cbor([2 | _]), do: abstain()
  def from_cbor([3 | _]), do: no_confidence()

  def to_cbor(%__MODULE__{} = drep) do
    case drep.drep_type do
      :key_hash -> [0, Cbor.as_byte(drep.drep_value)]
      :sctipt_hash -> [1, Cbor.as_byte(drep.drep_value)]
      :abstain -> [2]
      :no_confidence -> [3]
    end
  end
end
