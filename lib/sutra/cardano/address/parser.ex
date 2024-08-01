defmodule Sutra.Cardano.Address.Parser do
  @moduledoc """
    Contains function to encode and decode Cardano addresses based on cip-0019
    https://cips.cardano.org/cip/CIP-0019

  """

  import Bitwise

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Address.Parser
  alias Sutra.Cardano.Address.Pointer

  defimpl CBOR.Encoder, for: Address do
    @impl true
    def encode_into(address, acc) do
      Parser.encode(address) |> CBOR.Encoder.encode_into(acc)
    end
  end

  @doc """
  Encode an [Address] to CBOR.

  Byron addresses are left untouched as we don't plan to have full support of Byron era.

  Shelley address description from CIP-0019:

    Header type (tttt....)  Payment Part     Delegation Part
    (0) 0000....            PaymentKeyHash   StakeKeyHash
    (1) 0001....            ScriptHash       StakeKeyHash
    (2) 0010....            PaymentKeyHash   ScriptHash
    (3) 0011....            ScriptHash       ScriptHash
    (4) 0100....            PaymentKeyHash   Pointer
    (5) 0101....            ScriptHash       Pointer
    (6) 0110....            PaymentKeyHash   ø
    (7) 0111....            ScriptHash       ø

    Header type (....tttt)
    (0) ....0000 testnet
    (1) ....0001 mainnet

  For example, `61....(56 chars / 28 bytes)....` is an enterprise address (6, only a payment key) on mainnet (1).

  Stake address description from CIP-0019:

    Header type (tttt....)  Stake Reference
    (14) 1110....           StakeKeyHash
    (15) 1111....           ScriptHash
  """
  def encode(%Address{} = address) do
    network = if address.network == :testnet, do: "0", else: "1"

    {header_type, payload} =
      do_encode_address(
        address.address_type,
        address.payment_credential,
        address.stake_credential
      )

    header_type <> network <> payload
  end

  defp do_encode_address(:shelley, payment_credential, stake_credential) do
    case {payment_credential, stake_credential} do
      # (0) 0000.... PaymentKeyHash StakeKeyHash
      {%Credential{credential_type: :vkey} = p_cred, %Credential{credential_type: :vkey} = s_cred} ->
        {"0", p_cred.hash <> s_cred.hash}

      # (1) 0001.... ScriptHash StakeKeyHash
      {%Credential{credential_type: :script} = p_cred,
       %Credential{credential_type: :vkey} = s_cred} ->
        {"1", p_cred.hash <> s_cred.hash}

      # (2) 0010.... PaymentKeyHash ScriptHash
      {%Credential{credential_type: :vkey} = p_cred,
       %Credential{credential_type: :script} = s_cred} ->
        {"2", p_cred.hash <> s_cred.hash}

      # (3) 0011.... ScriptHash ScriptHash
      {%Credential{credential_type: :script} = p_cred,
       %Credential{credential_type: :script} = s_cred} ->
        {"3", p_cred.hash <> s_cred.hash}

      # (4) 0100.... PaymentKeyHash Pointer
      {%Credential{credential_type: :vkey} = _p_cred, %Pointer{} = _s_cred} ->
        raise "TODO: Implement Pointer encoding"

      # (5) 0101.... ScriptHash Pointer
      {%Credential{credential_type: :script} = _p_cred, %Pointer{} = _s_cred} ->
        raise "TODO: Implement Pointer encoding"

      # (6) 0110.... PaymentKeyHash  ø
      {%Credential{credential_type: :vkey} = p_cred, nil} ->
        {"6", p_cred.hash}

      # (7) 0111.... ScriptHash  ø
      {%Credential{credential_type: :script} = p_cred, nil} ->
        {"7", p_cred.hash}
    end
  end

  defp do_encode_address(:reward, nil, %Credential{} = stake_cred) do
    case stake_cred.credential_type do
      # (14) 1110.... StakeKeyHash
      :vkey -> {"e", stake_cred.hash}
      # (15) 1111.... ScriptHash
      :script -> {"f", stake_cred.hash}
    end
  end

  @spec decode(binary()) :: Address.t()
  def decode(bytes) do
    <<t1::1, t2::1, t3::1, t4::1, n1::1, n2::1, n3::1, n4::1, rest::bitstring>> = bytes
    address_header = [t1, t2, t3, t4]
    decoded_address = do_decode_bytes(address_header, rest)

    %Address{
      network: get_network([n1, n2, n3, n4]),
      address_type: decoded_address.address_type,
      payment_credential: decoded_address.payment_credential,
      stake_credential: decoded_address.stake_credential
    }
  end

  defp get_network([0, 0, 0, 0]), do: :testnet
  defp get_network([0, 0, 0, 1]), do: :mainnet

  # (0) 0000.... PaymentKeyHash StakeKeyHash
  defp do_decode_bytes([0, 0, 0, 0], bytes) do
    %{
      payment_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      stake_credential: %Credential{
        hash: binary_slice(bytes, 28, 28) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      address_type: :shelley
    }
  end

  # (1) 0001.... ScriptHash StakeKeyHash
  defp do_decode_bytes([0, 0, 0, 1], bytes) do
    %{
      payment_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      stake_credential: %Credential{
        hash: binary_slice(bytes, 28, 28) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      address_type: :shelley
    }
  end

  # (2) 0010.... PaymentKeyHash ScriptHash
  defp do_decode_bytes([0, 0, 1, 0], bytes) do
    %{
      payment_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      stake_credential: %Credential{
        hash: binary_slice(bytes, 28, 28) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      address_type: :shelley
    }
  end

  # (3) 0011.... ScriptHash ScriptHash
  defp do_decode_bytes([0, 0, 1, 1], bytes) do
    %{
      payment_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      stake_credential: %Credential{
        hash: binary_slice(bytes, 28, 28) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      address_type: :shelley
    }
  end

  # (4) 0100.... PaymentKeyHash Pointer
  defp do_decode_bytes([0, 1, 0, 0], bytes) do
    bytes_list = :binary.bin_to_list(bytes)
    {payment, pointer_bytes} = Enum.split(bytes_list, 28)

    {slot, remaining} = decode_variable_length(pointer_bytes)
    {index, remaining} = decode_variable_length(remaining)
    {cert_index, _} = decode_variable_length(remaining)

    %{
      payment_credential: %Credential{
        hash: :binary.list_to_bin(payment) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      stake_credential: %Pointer{slot: slot, tx_index: index, cert_index: cert_index},
      address_type: :shelley
    }
  end

  # (5) 0101.... ScriptHash Pointer
  defp do_decode_bytes([0, 1, 0, 1], bytes) do
    bytes_list = :binary.bin_to_list(bytes)
    {payment, pointer_bytes} = Enum.split(bytes_list, 28)

    {slot, remaining} = decode_variable_length(pointer_bytes)
    {index, remaining} = decode_variable_length(remaining)
    {cert_index, _} = decode_variable_length(remaining)

    %{
      payment_credential: %Credential{
        hash: :binary.list_to_bin(payment) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      stake_credential: %Pointer{slot: slot, tx_index: index, cert_index: cert_index},
      address_type: :shelley
    }
  end

  # (6) 0110.... PaymentKeyHash  ø
  defp do_decode_bytes([0, 1, 1, 0], bytes) do
    %{
      payment_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      stake_credential: nil,
      address_type: :shelley
    }
  end

  # (7) 0111.... ScriptHash  ø
  defp do_decode_bytes([0, 1, 1, 1], bytes) do
    %{
      payment_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      stake_credential: nil,
      address_type: :shelley
    }
  end

  # (8) 1000.... Byron
  defp do_decode_bytes([1, 0, 0, 0], _bytes) do
    raise "Not implemented: Byron Address"
  end

  # (9) 1110.... StakeKeyHash
  defp do_decode_bytes([1, 1, 1, 0], bytes) do
    %{
      payment_credential: nil,
      stake_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :vkey
      },
      address_type: :reward
    }
  end

  # (10) 1111.... ScriptHash
  defp do_decode_bytes([1, 1, 1, 1], bytes) do
    %{
      payment_credential: nil,
      stake_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :script
      },
      address_type: :reward
    }
  end

  defp do_decode_bytes(_, _), do: raise("Invalid address type")

  defp decode_variable_length(bytes) do
    Enum.reduce_while(bytes, {0, bytes}, fn byte, {val, [_ | t]} ->
      new_val = bor(val <<< 7, band(byte, 127))

      if band(byte, 128) == 0 do
        {:halt, {new_val, t}}
      else
        {:cont, {new_val, t}}
      end
    end)
  end
end
