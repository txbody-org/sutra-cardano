defmodule Sutra.Crypto.Key do
  @moduledoc """
    Bip32 Implementation for cardano
  """
  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Utils

  use TypedStruct

  import Bitwise, only: [&&&: 2, |||: 2, <<<: 2, >>>: 2]
  import Sutra.Utils, only: [maybe: 3]

  @hardened 2 ** 31
  @purpose 1852 + @hardened
  @coin_type 1815 + @hardened
  @pbkdf2_length 96
  @pbkdf2_iteration 4096

  typedstruct module: ExtendedKey do
    field(:payment_key, :binary)
    field(:stake_key, :binary)
  end

  typedstruct module: Ed25519key do
    field(:private_key, :binary)
  end

  typedstruct module: RootKey do
    field(:xprv, :binary)
    field(:chain_code, :binary)
  end

  @doc """
    Get Key from Bech32 encoded Keys
  """
  def from_bech32(bech_32_str) do
    case Bech32.decode(bech_32_str) do
      {:ok, hrp, data} -> from_bech32(hrp, data)
      _ -> {:error, "Invalid Bech32 Key"}
    end
  end

  def from_bech32("ed25519_sk", data) when is_binary(data),
    do: {:ok, %__MODULE__.Ed25519key{private_key: data}}

  def from_bech32("xprv", data) when is_binary(data) do
    <<l_key::binary-size(32), r_key::binary-size(32), rest::binary>> = data

    {:ok,
     %__MODULE__.RootKey{
       xprv: <<l_key::binary, r_key::binary>>,
       chain_code: rest
     }}
  end

  @doc """
    Fetch address from Keys
  """

  def address(key, network, account_index \\ 0, address_index \\ 0)

  def address(%__MODULE__.RootKey{} = root_key, network, acct_indx, addr_indx) do
    with {:ok, %__MODULE__.ExtendedKey{} = extended_key} <-
           derive_child(root_key, acct_indx, addr_indx) do
      address(extended_key, network)
    end
  end

  def address(%__MODULE__.Ed25519key{} = ed25519_key, network, _acct_indx, _addr_indx) do
    {:ok,
     pubkey_hash(ed25519_key)
     |> Address.from_verification_key(network)}
  end

  def address(%__MODULE__.ExtendedKey{} = extended_key, network, _acct_indx, _addr_indx) do
    payment_key_hash =
      public_key(extended_key, :payment_key) |> maybe(nil, &Blake2b.blake2b_224/1)

    stake_key_hash = public_key(extended_key, :stake_key) |> maybe(nil, &Blake2b.blake2b_224/1)

    {:ok, Address.from_verification_key(payment_key_hash, stake_key_hash, network)}
  end

  @doc """
    Returns Root Key from Mnemonic Words
    
    ## Examples

        iex(1)> mnemonic = "surround disagree build occur pluck main ..."
        ...(1)> root_key_from_mnemonic(mnemonic)
        ...(1)> %RootKey{}
  """
  def root_key_from_mnemonic(mnemonic) when is_binary(mnemonic) do
    seed = Mnemonic.mnemonic_to_entropy(mnemonic) |> Base.decode16!()

    <<l_key::binary-size(32), r_key::binary-size(32), rest::binary>> =
      :crypto.pbkdf2_hmac(:sha512, "", seed, @pbkdf2_iteration, @pbkdf2_length)

    {:ok,
     %__MODULE__.RootKey{
       xprv: <<tweak_bits(l_key)::binary, r_key::binary>>,
       chain_code: rest
     }}
  end

  @doc """
    Derives Payment & Stake Key at given index  

    ## Examples

        iex> derive_child(%RootKey{}, 0, 0)
        iex> %ExtendedKey{}

  """
  def derive_child(%RootKey{} = root_key, acct_indx, addr_indx)
      when is_integer(acct_indx) and is_integer(addr_indx) do
    hardened_path = [@purpose, @coin_type, acct_indx + @hardened]
    hardened_key = Enum.reduce(hardened_path, root_key, &do_derive_child_key/2)

    # payment path derivation "m/1852'/1815'/acct_idx'/0/addr_idx"
    payment_key =
      [0, addr_indx]
      |> Enum.reduce(hardened_key, &do_derive_child_key/2)
      |> Map.get(:xprv)

    # Stake path derivation "m/1852'/1815'/acct_idx'/2/0"
    stake_key =
      [2, 0]
      |> Enum.reduce(hardened_key, &do_derive_child_key/2)
      |> Map.get(:xprv)

    {:ok,
     %__MODULE__.ExtendedKey{
       payment_key: payment_key,
       stake_key: stake_key
     }}
  end

  @doc """
    Returns Public Key from Extended, Ed25519key
    
    ## Examples

        iex> public_key(%ExtendedKey{})
        iex> extended_verification_key

        iex> public_key(%ExtendedKey{}, :stake_key)
        iex> stake_verification_key

        iex> public_key(%Ed25519key{})
        iex> ed25519_public_key 
  """
  def public_key(key, key_type \\ :payment_key)

  def public_key(%__MODULE__.ExtendedKey{} = key, key_type) do
    Map.get(key, key_type)
    |> Utils.maybe(nil, fn v ->
      :binary.part(v, 0, 32)
      |> ExSodium.Ed25519.scalarmult_base_no_clamp()
    end)
  end

  def public_key(%__MODULE__.Ed25519key{private_key: p_key}, _) do
    :crypto.generate_key(:eddsa, :ed25519, p_key)
    |> Utils.fst()
  end

  def public_key(raw_extended_key, _) when is_binary(raw_extended_key) do
    raw_extended_key
    |> :binary.part(0, 32)
    |> ExSodium.Ed25519.scalarmult_base_no_clamp()
  end

  def pubkey_hash(key, opts \\ [])

  def pubkey_hash(%__MODULE__.ExtendedKey{} = key, opts) do
    key_type = opts[:key_type] || :payment_key
    public_key(key, key_type) |> Blake2b.blake2b_224()
  end

  def pubkey_hash(raw_extended_key, _) when is_binary(raw_extended_key) do
    public_key(raw_extended_key) |> Blake2b.blake2b_224()
  end

  def pubkey_hash(%__MODULE__.Ed25519key{} = key, _opts),
    do: public_key(key) |> Blake2b.blake2b_224()

  def sign(%__MODULE__.ExtendedKey{payment_key: payment_key}, payload)
      when is_binary(payload), do: sign(payment_key, payload)

  def sign(raw_extended_key, payload) when is_binary(raw_extended_key) and is_binary(payload) do
    <<scalar::binary-size(32), iv::binary-size(32), _chain_code::binary>> = raw_extended_key

    pub_key = ExSodium.Ed25519.scalarmult_base_no_clamp(scalar)

    nonce =
      (iv <> payload)
      |> ExSodium.Ed25519.hash_sha512()
      |> ExSodium.Ed25519.scalar_reduce()

    r = ExSodium.Ed25519.scalarmult_base_no_clamp(nonce)

    s =
      (r <> pub_key <> payload)
      |> ExSodium.Ed25519.hash_sha512()
      |> ExSodium.Ed25519.scalar_reduce()
      |> ExSodium.Ed25519.scalar_mul(scalar)
      |> ExSodium.Ed25519.scalar_add(nonce)

    r <> s
  end

  def sign(%__MODULE__.Ed25519key{private_key: key}, payload) when is_binary(payload) do
    priv_key = :binary.part(key, 0, 32)
    :crypto.sign(:eddsa, :none, payload, [priv_key, :ed25519])
  end

  defp do_derive_child_key(index, %__MODULE__.RootKey{} = key) do
    # Extract the scalar and iv parts from the extended private key
    <<parent_key_left::binary-size(32), paren_key_right::binary-size(32), _rest::binary>> =
      key.xprv

    {z_data, chain_code_data} =
      if index >= @hardened do
        # for hardened keys (i >= 2 ^ 31)
        # Z := HMAC_512(0x00||kP ||i)
        # CHAIN_CODE:= (0x01 || kP || i  )
        {
          <<0x00, parent_key_left::binary, paren_key_right::binary, index::little-32>>,
          <<0x01, parent_key_left::binary, paren_key_right::binary, index::little-32>>
        }
      else
        # For Non hardened Keys (i < 2 ^ 31)
        # Z := HMAC_512 (0x02|| AP ||i)
        # CHAIN_CODE := (0x03|| AP ||i)

        ap = ExSodium.Ed25519.scalarmult_base_no_clamp(parent_key_left)

        {
          <<0x02, ap::binary, index::little-32>>,
          <<0x03, ap::binary, index::little-32>>
        }
      end

    <<z_left::binary-size(32), z_right::binary-size(32)>> =
      :crypto.mac(:hmac, :sha512, key.chain_code, z_data)

    child_left = scalar_mul_8(z_left, parent_key_left)
    child_right = handle_mod_256(z_right, paren_key_right)

    <<_::binary-size(32), child_chain_code::binary-size(32)>> =
      :crypto.mac(:hmac, :sha512, key.chain_code, chain_code_data)

    %__MODULE__.RootKey{
      xprv: <<child_left::binary, child_right::binary>>,
      chain_code: child_chain_code
    }
  end

  defp scalar_mul_8(zl, kl) do
    k_bytes = :binary.bin_to_list(kl)
    z_bytes = :binary.bin_to_list(zl)

    with_index = Enum.zip(z_bytes, k_bytes) |> Enum.zip(0..31)

    # Process each byte with carry
    {result_bytes, _} =
      Enum.reduce(with_index, {<<>>, 0}, fn
        {{z_byte, k_byte}, i}, {acc, carry} when i < 28 ->
          # For bytes 0-27, multiply zL by 8 and add
          r = k_byte + (z_byte <<< 3) + carry
          new_byte = r &&& 0xFF
          new_carry = r >>> 8
          {<<acc::binary, new_byte>>, new_carry}

        {{_z_byte, k_byte}, _i}, {acc, carry} ->
          # For bytes 28-31, only add carry
          r = k_byte + carry
          new_byte = r &&& 0xFF
          new_carry = r >>> 8
          {<<acc::binary, new_byte>>, new_carry}
      end)

    result_bytes
  end

  defp tweak_bits(bytes) do
    <<first_byte, middle::binary-size(30), last_byte>> = bytes

    # Clear bits 0, 1, 2 of first byte
    cleared_first_byte = first_byte &&& 0b11111000

    # Clear bit 7 and set bit 6 of last byte
    modified_last_byte = (last_byte &&& 0b11111) ||| 0b1000000

    # Combine all parts
    <<cleared_first_byte, middle::binary, modified_last_byte>>
  end

  defp handle_mod_256(z_r, pk_r) do
    Enum.zip(:binary.bin_to_list(z_r), :binary.bin_to_list(pk_r))
    |> Enum.reduce({<<>>, 0}, fn {z, p}, {acc, carry} ->
      r = z + p + carry
      {<<acc::binary, r>>, r >>> 8}
    end)
    |> Utils.fst()
  end
end
