defmodule Sutra.Crypto do
  @moduledoc """
    Module to handle PublicKey/PrivateKey 
  """

  # TODO: Make better function
  def derive_privkey_from_bech32("ed25519_sk" <> _ = bech32_str) do
    case Bech32.decode(bech32_str) do
      {:ok, _hrp, data} -> {:ok, data}
      _ -> {:error, "Invalid Bech32 Private Key"}
    end
  end

  def derive_privkey_from_bech32(_), do: {:error, "Invalid Bech32 encoded signing key"}

  def derive_keys(raw_binary) do
    priv_key = :binary.part(raw_binary, 0, 32)
    :crypto.generate_key(:eddsa, :ed25519, priv_key)
  end

  def sign(payload, priv_key) do
    :crypto.sign(:eddsa, :none, payload, [priv_key, :ed25519])
  end
end
