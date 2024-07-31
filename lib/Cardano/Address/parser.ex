defmodule Cardano.Address.Parser do
  @moduledoc """
    Cardano Address Parser
  """

  import Bitwise

  alias Cardano.Address
  alias Cardano.Address.Credential
  alias Cardano.Address.Pointer

  def decode(bytes) do
    <<t1::1, t2::1, t3::1, t4::1, n1::1, n2::1, n3::1, n4::1, rest::bitstring>> = bytes
    address_header = [t1, t2, t3, t4]
    network = get_network([n1, n2, n3, n4])
    decoded_address = do_decode_bytes(address_header, rest)

    %Address{
      network: network,
      address_type: decoded_address.address_type,
      payment_credential: decoded_address.payment_credential,
      stake_credential: decoded_address.stake_credential
    }
  end

  defp get_network([0, 0, 0, 0]), do: :testnet
  defp get_network([0, 0, 0, 1]), do: :mainnet

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

  defp do_decode_bytes([1, 0, 0, 0], _bytes) do
    raise "Not implemented: Byron Address"
  end

  defp do_decode_bytes([1, 1, 1, 0], bytes) do
    %{
      payment_credential: nil,
      stake_credential: %Credential{
        hash: binary_slice(bytes, 0, 28) |> Base.encode16(case: :lower),
        credential_type: :skey
      },
      address_type: :reward
    }
  end

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
