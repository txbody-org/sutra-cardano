defmodule Sutra.Cardano.Transaction.TxBuilder do
  @moduledoc """
    building blocks to build Transaction in Cardano
  """
  alias __MODULE__.Internal
  alias __MODULE__.TxConfig
  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.Witness
  alias Sutra.Cardano.Transaction.Witness.PlutusData
  alias Sutra.Cardano.Transaction.Witness.Redeemer
  alias Sutra.Cardano.Transaction.Witness.VkeyWitness
  alias Sutra.Data
  alias Sutra.ProtocolParams

  use TypedStruct

  @def_script_lookup %{
    native: %{},
    plutus_v1: %{},
    plutus_v2: %{},
    plutus_v3: %{}
  }

  @type t() :: %__MODULE__{
          mints: %{Asset.policy_id() => %{Asset.asset_name() => integer()}},
          metadata: any(),
          ref_inputs: [%Input{}],
          inputs: [%Input{}],
          outputs: [Output.t()],
          required_signers: MapSet.t(),
          scripts_lookup: %{Script.script_type() => Script.script_data()},
          plutus_data: [PlutusData.t()],
          collateral_input: OutputReference.t(),
          redeemer_lookup: %{{Redeemer.redeemer_tag(), binary()} => PlutusData.t()},
          config: %TxConfig{}
        }

  defstruct mints: %{},
            metadata: nil,
            ref_inputs: [],
            inputs: [],
            outputs: [],
            required_signers: MapSet.new(),
            scripts_lookup: @def_script_lookup,
            plutus_data: [],
            config: %TxConfig{},
            collateral_input: nil,
            redeemer_lookup: %{},
            valid_from: nil,
            valid_to: nil

  def new_tx do
    %__MODULE__{
      config: %TxConfig{provider: Application.get_env(:sutra, :provider)}
    }
  end

  def use_provider(%__MODULE__{config: cfg} = builder, provider) when not is_nil(provider) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :provider, provider)}
  end

  def set_protocol_params(%__MODULE__{config: cfg} = builder, %ProtocolParams{} = protocol_params) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :protocol_params, protocol_params)}
  end

  def set_wallet_address(%__MODULE__{config: cfg} = builder, %Address{} = address) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :wallet_address, address)}
  end

  def set_change_address(
        %__MODULE__{config: cfg, plutus_data: prev_plutus_data} = builder,
        %Address{} = address,
        opts \\ []
      ) do
    {new_plutus_data, change_datum} = set_datum(prev_plutus_data, opts[:datum])

    %__MODULE__{
      builder
      | plutus_data: new_plutus_data,
        config: %TxConfig{cfg | change_address: address, change_datum: change_datum}
    }
  end

  @doc """
    proper docs Needed:
  """
  def spend(%__MODULE__{} = builder, inputs, redeemer_data \\ nil) do
    new_redeemer =
      if redeemer_data == nil,
        do: builder.redeemer_lookup,
        else:
          Enum.reduce(inputs, builder.redeemer_lookup, fn i, acc ->
            Map.put(acc, {:spend, Internal.extract_ref(i)}, redeemer_data)
          end)

    %__MODULE__{
      builder
      | inputs: builder.inputs ++ inputs,
        redeemer_lookup: new_redeemer
    }
  end

  @doc """
  appends output
  """
  def put_output(%__MODULE__{} = builder, %Output{} = output, datum \\ nil) do
    {new_plutus_data, datum} = set_datum(builder.plutus_data, datum)

    %__MODULE__{
      builder
      | outputs: [%Output{output | datum: datum} | builder.outputs],
        plutus_data: new_plutus_data
    }
  end

  def pay_to_address(builder, address, assets, opts \\ [])

  def pay_to_address(builder, address, assets, opts) when is_binary(address) do
    builder
    |> pay_to_address(Address.from_bech32(address), assets, opts)
  end

  def pay_to_address(builder, address = %Address{}, assets, opts) when is_map(assets) do
    output = %Output{
      address: address,
      value: assets,
      reference_script: Keyword.get(opts, :ref_script)
    }

    put_output(builder, output, opts[:datum])
  end

  defp set_datum(prev_plutus_data, nil), do: {prev_plutus_data, nil}

  defp set_datum(prev_plutus_data, {:inline, data}) when is_binary(data),
    do: {prev_plutus_data, %Datum{kind: :inline_datum, value: data}}

  defp set_datum(prev_plutus_data, {:as_hash, data}) when is_binary(data) do
    plutus_data = [Data.decode!(data) | prev_plutus_data]
    {plutus_data, %Datum{kind: :datum_hash, value: Blake2b.blake2b_256(data)}}
  end

  defp set_datum(prev_plutus_data, {:hash, hashed_data}) when is_binary(hashed_data) do
    {prev_plutus_data, %Datum{kind: :datum_hash, value: hashed_data}}
  end

  def attach_metadata(%__MODULE__{} = builder, label, metadata)
      when not is_nil(metadata) and is_integer(label),
      do: %__MODULE__{builder | metadata: Map.put(%{}, label, metadata)}

  def add_signer(
        %__MODULE__{} = builder,
        %Address{
          payment_credential: %Credential{credential_type: :vkey, hash: v_key_hash}
        }
      ),
      do: %__MODULE__{
        builder
        | required_signers: MapSet.put(builder.required_signers, v_key_hash)
      }

  def attach_datum(builder = %__MODULE__{}, datum) when not is_nil(datum) do
    %__MODULE__{builder | plutus_data: [datum | builder.plutus_data]}
  end

  def attach_script(
        %__MODULE__{scripts_lookup: script_lookup} = builder,
        %Script{} = script
      ) do
    updated_script_lookup =
      Map.put_new(script_lookup[script.script_type] || %{}, Script.hash_script(script), script)

    %__MODULE__{
      builder
      | scripts_lookup: Map.put(script_lookup, script.script_type, updated_script_lookup)
    }
  end

  def mint_asset(
        %__MODULE__{mints: prev_mints, redeemer_lookup: prev_redeemer} =
          builder,
        policy_id,
        asset,
        redeemer_data \\ nil
      )
      when not is_nil(redeemer_data) and is_binary(policy_id) and is_map(asset) do
    if Map.get(prev_redeemer, {:mint, policy_id}) do
      raise "Same asset is already Minted. You can only mint asset once"
    else
      %__MODULE__{
        builder
        | mints: Map.put(prev_mints, policy_id, asset),
          redeemer_lookup: Map.put(prev_redeemer, {:mint, policy_id}, redeemer_data)
      }
    end
  end

  def valid_from(%__MODULE__{} = builder, time) when is_integer(time) do
    %__MODULE__{
      builder
      | valid_from: time
    }
  end

  def valid_to(%__MODULE__{} = builder, time) when is_integer(time) do
    %__MODULE__{
      builder
      | valid_to: time
    }
  end

  @doc """
    Build Final
  """
  def build_tx(%__MODULE__{} = builder, opts \\ []) do
    final_cfg = TxConfig.__setup(builder.config, opts) |> TxConfig.__init()

    collateral_ref = opts[:collateral_ref]

    final_builder = %__MODULE__{
      builder
      | config: final_cfg
    }

    # FIXME: Maybe wallet_utxos is not needed in config and can be fetched from here
    with {:ok, %Transaction{} = tx} <-
           Internal.finalize_tx(final_builder, final_cfg.wallet_utxos, collateral_ref) do
      tx
    end
  end

  def sign_tx(%Transaction{witnesses: %Witness{} = witness} = tx, signers) do
    tx_hash = Transaction.tx_id(tx) |> Base.decode16!(case: :mixed)

    new_vkey_witness =
      Enum.reduce(signers, MapSet.new(witness.vkey_witness), fn sk, acc ->
        {:ok, raw_key} =
          Sutra.Crypto.derive_privkey_from_bech32(sk)

        {pub_key, priv_key} = Sutra.Crypto.derive_keys(raw_key)

        MapSet.put(acc, %VkeyWitness{
          vkey: pub_key,
          signature: Sutra.Crypto.sign(tx_hash, priv_key)
        })
      end)

    %Transaction{
      tx
      | witnesses: %Witness{witness | vkey_witness: MapSet.to_list(new_vkey_witness)}
    }
  end

  def submit_tx(%Transaction{} = signed_tx) do
    provider = Application.get_env(:sutra, :provider)
    submit_tx(signed_tx, provider)
  end

  def submit_tx(%Transaction{} = signed_tx, provider) do
    cbor = signed_tx |> Transaction.to_cbor() |> CBOR.encode()

    provider.__struct__.submit(provider, cbor)
  end

  def get_change_address([%Address{} = addr | _], nil), do: addr
  def get_change_address(_, %Address{} = addr), do: addr
end
