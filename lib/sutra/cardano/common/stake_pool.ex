defmodule Sutra.Cardano.Common.StakePool do
  alias Sutra.Utils

  @doc """
  """
  def from_bech32("pool" <> _ = pool_bech32) do
    case Bech32.decode(pool_bech32) do
      {:ok, _hrp, data} -> {:ok, Base.encode16(data, case: :lower)}
      _ -> {:error, :invalid_pool_bech32}
    end
  end

  def from_bech32(_), do: {:error, :invalid_pool_bech32}

  def to_bech32(pool_keyhash) do
    decoded_hash = Utils.ok_or(Base.decode16(pool_keyhash, case: :mixed), pool_keyhash)
    Bech32.encode("pool", decoded_hash)
  end
end
