defmodule Sutra.Blake2b do
  @moduledoc """
    Helper function to calculate blake2b hash
  """
  alias Blake2.Blake2b

  @type blake2b_256() :: String.t()
  @type blake2b_224() :: String.t()

  @doc """
    Returns a 32-byte  digest.
  """
  @spec blake2b_256(binary()) :: binary()
  def blake2b_256(data) do
    Blake2b.hash_hex(data, "", 32)
  end

  @doc """
    Returns a 28-byte  digest.
  """
  def blake2b_224(data) do
    Blake2b.hash_hex(data, "", 28)
  end
end
