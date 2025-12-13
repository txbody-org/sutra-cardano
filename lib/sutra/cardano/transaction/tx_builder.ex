defmodule Sutra.Cardano.Transaction.TxBuilder do
  @moduledoc """
  building blocks to build Transaction in Cardano
  """
  require Sutra.Cardano.Script
  require Sutra.Data.Plutus

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.TxBuilder.CertificateHelper
  alias Sutra.Cardano.Transaction.TxBuilder.Internal
  alias Sutra.Cardano.Transaction.TxBuilder.TxConfig
  alias Sutra.Cardano.Transaction.Witness
  alias Sutra.Cardano.Transaction.Witness.VkeyWitness
  alias Sutra.Crypto.Key
  alias Sutra.Data
  alias Sutra.Data.Plutus
  alias Sutra.ProtocolParams
  alias Sutra.Provider

  import Sutra.Utils, only: [maybe: 2]

  defstruct config: %TxConfig{},
            inputs: [],
            outputs: [],
            ref_inputs: [],
            errors: [],
            mints: %{},
            script_lookup: %{},
            required_signers: MapSet.new(),
            plutus_data: %{},
            valid_to: nil,
            valid_from: nil,
            redeemer_lookup: %{},
            metadata: nil,
            used_scripts: MapSet.new(),
            collateral_inputs: [],
            certificates: [],
            total_deposit: Asset.zero(),
            withdrawals: %{}

  @doc """
  Initialize TxBuilder with default values

    ## Examples

      iex> new_tx()
      %TxBuilder{}
  """
  def new_tx do
    %__MODULE__{
      config: %TxConfig{}
    }
  end

  @doc """
  overrides provider

    ## Examples

      iex(1)> new_tx()  |> use_provider(KoiosProvider)
      %TxBuilder{}

  """
  def use_provider(%__MODULE__{config: cfg} = builder, provider) when not is_nil(provider) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :provider, provider)}
  end

  @doc """
  use custom protocol params

    ## Examples

        iex(1)>  new_tx() |> set_protocol_params(%ProtocolParams{})
        %TxBuilder{}
  """
  def set_protocol_params(%__MODULE__{config: cfg} = builder, %ProtocolParams{} = protocol_params) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :protocol_params, protocol_params)}
  end

  @doc """
  Set Wallet address
    
    ## Examples
      
      iex> new_tx() |> set_wallet_address(%Address{})
      %TxBuilder{}

      iex> new_tx() |> set_wallet_address([%Address{}, %Address{}])
      %TxBuilder{}
  """
  def set_wallet_address(%__MODULE__{config: cfg} = builder, %Address{} = address) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :wallet_address, [address])}
  end

  def set_wallet_address(%__MODULE__{config: cfg} = builder, addresses) when is_list(addresses) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :wallet_address, addresses)}
  end

  @doc """
  Set Custom change address

    ## Examples
    
        iex> new_tx() |> set_change_address(%Address{})
        %TxBuilder{}

        # Change Address with datum 
        iex> new_tx() |> set_change_address(%Address{}, {:inline_datum, some_plutus_data})
        %TxBuilder{}
  """
  def set_change_address(
        %__MODULE__{config: %TxConfig{} = cfg, plutus_data: prev_plutus_data} = builder,
        %Address{} = address,
        datum \\ nil
      ) do
    {new_plutus_data, datum_info} = extract_datum(datum)

    new_plutus_data =
      if datum_info.kind == :datum_hash,
        do: [new_plutus_data | prev_plutus_data],
        else: prev_plutus_data

    change_datum_info = if datum_info.kind == :no_datum, do: cfg.change_datum, else: datum_info

    %__MODULE__{
      builder
      | plutus_data: new_plutus_data,
        config: %TxConfig{cfg | change_address: address, change_datum: change_datum_info}
    }
  end

  @doc """
  Adds Inputs To Transaction

  ## Parameters
    
      - `%TxBuilder{}` - The TxBuilder instance containing the transaction details.
      - `inputs`    - The list of `%Input{}` trying to spend

  ## Options 
      - `witness`   - The witness for input. Can be `%Script{}`, `%NativeScript{}`, `:vkey_witness`, `%Input{}`, `:ref_scripts` based on input. (defaults to `:vkey_witness`)
      - `redeemer`  - Redeemer for spending inputs if needed. 
                      Required only for inputs trying to consume from script address

      - `datum`     - The datum info needed to spend utxos from script. Useful only for utxos with datum type `datum_hash`. 
                      Note: If Datum is already available from provider for input, datum will be overriden by datum fetched from provider

  ## Examples
    
      iex> new_tx() |> add_input(inputs_from_user_wallet)
      %TxBuilder{}

      iex> new_tx() |> add_input(native_script_inputs, witness: %NativeScript{})
      %TxBuilder{}

      iex> new_tx() |> add_input(script_inputs, witness: %Script{}, redeemer: redeemer_info)
      %TxBuilder{}
      
      # Pass Input as reference_script
      iex> new_tx() |> add_input(script_inputs, witness: %Input{}, redeemer: redeemer_info)
      %TxBuilder{}
      
      # If script is already added as reference_script in pipeline we can 
      # simply pass :ref_inputs
      iex> new_tx() |> add_input(script_inputs, witness: :ref_inputs, redeemer: redeemer_info)
      %TxBuilder{}
   
    
  """
  def add_input(%__MODULE__{} = cfg, [%Input{} | _] = inputs, opts \\ []) do
    witness = opts[:witness] || :vkey_witness
    redeemer = opts[:redeemer]
    passed_datum = opts[:datum]

    Enum.reduce(inputs, cfg, fn %Input{output: output} = input, %__MODULE__{} = acc_cfg ->
      exact_datum = output.datum_raw || passed_datum
      # Add datum in witness if input has datum with DatumHash kind
      new_plutus_data =
        if Datum.datum_kind(output.datum) == :datum_hash and not is_nil(exact_datum),
          do: Map.put_new(cfg.plutus_data, output.datum.value, exact_datum),
          else: cfg.plutus_data

      case validate_script_witness(cfg.script_lookup, input, redeemer, witness) do
        # Spending for Varification Key as payment Credential
        {:ok, :vkey_witness, _} ->
          %__MODULE__{
            acc_cfg
            | inputs: [input | acc_cfg.inputs],
              plutus_data: new_plutus_data
          }

        # Spending from Script Address
        {:ok, used_script_type, witness_key} ->
          %__MODULE__{
            acc_cfg
            | inputs: [input | acc_cfg.inputs],
              script_lookup: Map.put_new(acc_cfg.script_lookup, witness_key, witness),
              used_scripts: MapSet.put(cfg.used_scripts, used_script_type),
              plutus_data: new_plutus_data,
              redeemer_lookup:
                Map.put_new(cfg.redeemer_lookup, {:spend, Input.extract_ref(input)}, redeemer)
          }

        {:error, err_key} ->
          %__MODULE__{
            acc_cfg
            | errors: [%{key: err_key, value: input} | acc_cfg.errors]
          }
      end
    end)
  end

  def add_reference_inputs(%__MODULE__{} = builder, [%Input{} | _] = inputs) do
    new_script_lookup =
      Enum.reduce(inputs, builder.script_lookup, fn %Input{} = input, acc ->
        if Script.script?(input.output.reference_script),
          do: Map.put(acc, Script.hash_script(input.output.reference_script), input),
          else: acc
      end)

    %__MODULE__{
      ref_inputs: builder.ref_inputs ++ inputs,
      script_lookup: new_script_lookup
    }
  end

  # Checks if inputs is valid with correct redeemer and witness
  defp validate_script_witness(
         _script_lookup,
         %Input{
           output: %Output{
             address: %Address{
               payment_credential: %Credential{credential_type: :vkey, hash: vkey_hash}
             }
           }
         },
         _redeemer,
         _witness
       ),
       do: {:ok, :vkey_witness, vkey_hash}

  defp validate_script_witness(
         script_lookup,
         %Input{
           output: %Output{
             address: %Address{payment_credential: %Credential{hash: script_hash}}
           }
         },
         redeemer,
         witness
       ),
       do: validate_script_witness(script_lookup, script_hash, redeemer, witness)

  defp validate_script_witness(script_lookup, script_hash, redeemer, witness) do
    exact_witness =
      if witness == :ref_inputs,
        do: extract_from_script_lookup(script_lookup[script_hash]),
        else: witness

    used_script_type =
      if Script.is_plutus_script(exact_witness), do: exact_witness.script_type, else: :native

    cond do
      not Script.script?(exact_witness) ->
        {:error, :missing_script_witness}

      Script.hash_script(exact_witness) != script_hash ->
        {:error, :invalid_script_witness}

      Script.is_plutus_script(exact_witness) and not Plutus.is_plutus_data(redeemer) ->
        {:error, :invalid_redeemer}

      true ->
        {:ok, used_script_type, script_hash}
    end
  end

  defp extract_from_script_lookup(%Input{output: %Output{reference_script: script}}), do: script
  defp extract_from_script_lookup(_), do: nil

  @doc """

  Creates Output in transaction.

    ## Examples
      
      iex> add_output(%TxBuilder{}, %Output{})
      %TxBuilder{}
      
      # Creates output without Datum
      iex> add_output(%TxBuilder{}, %Address{} = address, asset)
      %TxBuilder{}
      
      # Creates output with inline datum
      iex> add_output(%TxBuilder{}, %Address{} = address, asset, {:inline_datum, plutus_data})
      %TxBuilder{}

      # Creates output with datum hash
      iex> add_output(%TxBuilder{}, %Address{} = address, asset, {:datum_hash, plutus_data})
      %TxBuilder{}
      
  """
  def add_output(%__MODULE__{} = cfg, %Output{} = output) do
    plutus_data =
      if Datum.datum_kind(output.datum) == :datum_hash and not is_nil(output.datum_raw),
        do: Map.put_new(cfg.plutus_data, output.datum.value, output.datum_raw),
        else: cfg.plutus_data

    %__MODULE__{cfg | outputs: [output | cfg.outputs], plutus_data: plutus_data}
  end

  def add_output(%__MODULE__{} = cfg, %Address{} = out_addr, assets, datum \\ nil) do
    {plutus_data, datum_info} = extract_datum(datum)
    output = %Output{address: out_addr, value: assets, datum: datum_info, datum_raw: plutus_data}
    add_output(cfg, output)
  end

  defp extract_datum({:inline_datum, val}) do
    raw_data = Data.encode(val)

    {Data.decode!(raw_data), Datum.inline(raw_data)}
  end

  defp extract_datum({:datum_hash, val}) do
    raw_data = Data.encode(val)
    {Data.decode!(raw_data), Datum.datum_hash(Blake2b.blake2b_256(raw_data))}
  end

  defp extract_datum(_), do: {nil, Datum.no_datum()}

  @doc """
  Mint Assets 

    ## Parameters
    
      - `%TxBuilder{}` - The TxBuilder instance containing the transaction details.
      - `policy_id` - policy_id of token being minted
      - `assets`  - Assets being minted under some policy
      - `minting_policy` - The Minting Policy can be Either `%Script{}`, %NativeScript{}, :ref_inputs
      - `redeemer` - Redeemer for minting policy. Needed for Plutus script Minting policy

    ## Examples
      
      iex> mint_asset(%TxBuilder{}, %{"asset1.." => 1}, %NativeScript{})
      %TxBuilder{}

      iex> mint_asset(%TxBuilder{}, %{"asset.." => -1}, %Script{}, some_redeemer)
      %TxBuilder{}
  """
  def mint_asset(builder, policy_id, assets, policy, redeemer \\ nil)

  # Already minted same token
  def mint_asset(%__MODULE__{mints: mints} = cfg, policy_id, _, _, _)
      when is_map_key(mints, policy_id),
      do: %__MODULE__{
        cfg
        | errors: [%{key: :multiple_mints, value: policy_id} | cfg.errors]
      }

  def mint_asset(%__MODULE__{} = cfg, policy_id, assets, minting_policy, redeemer)
      when Script.is_script(minting_policy) or minting_policy == :ref_inputs do
    case validate_script_witness(cfg.script_lookup, policy_id, redeemer, minting_policy) do
      {:ok, used_script_type, _} ->
        new_redeemer_lookup =
          if is_nil(redeemer),
            do: cfg.redeemer_lookup,
            else: Map.put_new(cfg.redeemer_lookup, {:mint, policy_id}, redeemer)

        %__MODULE__{
          cfg
          | mints: Map.put_new(cfg.mints, policy_id, assets),
            script_lookup: Map.put_new(cfg.script_lookup, policy_id, minting_policy),
            used_scripts: MapSet.put(cfg.used_scripts, used_script_type),
            redeemer_lookup: new_redeemer_lookup
        }

      {:error, :invalid_script_witness} ->
        %__MODULE__{
          cfg
          | errors: [%{key: :invalid_minting_policy, value: policy_id} | cfg.errors]
        }

      {:error, :missing_script_witness} ->
        %__MODULE__{
          cfg
          | errors: [%{key: :missing_minting_policy, value: policy_id} | cfg.errors]
        }

      {:error, :invalid_redeemer} ->
        %__MODULE__{
          cfg
          | errors: [%{key: :invalid_redeemer_for_policy, value: policy_id} | cfg.errors]
        }
    end
  end

  @doc """
  Creates output with reference script

  ## Parameters

    - `%TxBuilder{}` - The TxBuilder instance containing the transaction details.
    - `%Address{}` - The Address where UtXo with reference script will be sent.
    - `Script`  - The script to attach as reference script. Can be either `Plutus Script` or `NativeScript`

  ##  Examples
    
      iex> deploy_script(%TxBuilder{}, %Address{}, %Script{})
      %TxBuilder{}

      iex> deploy_script(%TxBuilder{}, %Address{}, %NativeScript{})
      %TxBuilder{}

  """
  def deploy_script(%__MODULE__{} = cfg, %Address{} = out_addr, script)
      when Script.is_script(script) do
    output = %Output{
      address: out_addr,
      reference_script: script,
      datum: Datum.no_datum(),
      value: Asset.zero()
    }

    add_output(cfg, output)
  end

  @doc """
  Appends Signer as Required Signers in TxBody

  ## Examples

      iex> add_signer(%TxBuilder{}, %Address{})
      %TxBuilder{}

      iex> add_signer(%TxBuilder{}, payment_key_hash)
      %TxBuilder{}

  """
  def add_signer(
        %__MODULE__{} = cfg,
        %Address{payment_credential: %Credential{} = payment_credential} = addr
      ) do
    if Address.vkey_address?(addr),
      do: %__MODULE__{
        cfg
        | required_signers: MapSet.put(cfg.required_signers, payment_credential.hash)
      },
      else: %__MODULE__{cfg | errors: [%{key: :invalid_payment_signer, value: addr}]}
  end

  def add_signer(
        %__MODULE__{} = cfg,
        pubkey_hash
      )
      when is_binary(pubkey_hash) do
    %__MODULE__{
      cfg
      | required_signers: MapSet.put(cfg.required_signers, pubkey_hash)
    }
  end

  @doc """
  Attach plutus data in witness

  ## Examples
    
    iex> attach_datum(%TxBuilder{}, %Constr{})
    %TxBuilder{}

  """
  def attach_datum(%__MODULE__{} = cfg, datum) do
    encoded_datum = Data.encode(datum)

    %__MODULE__{
      cfg
      | plutus_data:
          Map.put_new(
            cfg.plutus_data,
            Blake2b.blake2b_256(encoded_datum),
            Data.decode!(encoded_datum)
          )
    }
  end

  @doc """
  Attach Metadata to Transaction

  ## Examples

    iex> attach_metadata(%TxBuilder{}, 721, metadata_info)
    %TxBuilder{}  
    
  """
  def attach_metadata(%__MODULE__{} = builder, label, metadata)
      when not is_nil(metadata) and is_integer(label) do
    %__MODULE__{builder | metadata: Map.put(%{}, label, metadata)}
  end

  def valid_from(%__MODULE__{} = cfg, %DateTime{} = dt) do
    %__MODULE__{cfg | valid_from: DateTime.to_unix(dt, :millisecond)}
  end

  def valid_from(%__MODULE__{} = cfg, timestamp) when is_integer(timestamp),
    do: %__MODULE__{cfg | valid_from: timestamp}

  def valid_to(%__MODULE__{} = cfg, %DateTime{} = dt) do
    %__MODULE__{cfg | valid_from: DateTime.to_unix(dt, :millisecond)}
  end

  def valid_to(%__MODULE__{} = cfg, timestamp) when is_integer(timestamp),
    do: %__MODULE__{cfg | valid_to: timestamp}

  def set_change_datum(%__MODULE__{} = cfg, datum) when Plutus.is_plutus_data(datum) do
    %__MODULE__{cfg | config: TxConfig.__set_cfg(cfg.config, :change_datum, datum)}
  end

  def withdraw_stake(
        %__MODULE__{} = cfg,
        %Address{
          stake_credential: %Credential{credential_type: :vkey, hash: stake_hash}
        },
        lovelace
      )
      when is_integer(lovelace) do
    %__MODULE__{
      cfg
      | withdrawals: Map.put_new(cfg.withdrawals, stake_hash, Asset.from_lovelace(lovelace))
    }
  end

  def withdraw_stake(%__MODULE__{} = cfg, native_script, lovelace)
      when Script.is_native_script(native_script) and is_integer(lovelace) do
    script_hash = Script.hash_script(native_script)

    %__MODULE__{
      cfg
      | withdrawals: Map.put_new(cfg.withdrawals, script_hash, Asset.from_lovelace(lovelace)),
        script_lookup: Map.put_new(cfg.script_lookup, script_hash, native_script),
        used_scripts: MapSet.put(cfg.used_scripts, :native)
    }
  end

  def withdraw_stake(%__MODULE__{} = cfg, plutus_script, redeemer, lovelace)
      when Script.is_plutus_script(plutus_script) and is_integer(lovelace) and
             Plutus.is_plutus_data(redeemer) do
    script_hash = Script.hash_script(plutus_script)

    %__MODULE__{
      cfg
      | withdrawals: Map.put_new(cfg.withdrawals, script_hash, Asset.from_lovelace(lovelace)),
        script_lookup: Map.put_new(cfg.script_lookup, script_hash, plutus_script),
        used_scripts: MapSet.put(cfg.used_scripts, plutus_script.script_type),
        redeemer_lookup: Map.put_new(cfg.redeemer_lookup, {:reward, script_hash}, redeemer)
    }
  end

  @doc delegate_to: {CertificateHelper, :register_stake_credential, 3}
  defdelegate register_stake_credential(builder, credential, redeemer \\ nil),
    to: CertificateHelper

  @doc delegate_to: {CertificateHelper, :delegate_vote, 3}
  defdelegate delegate_vote(builder, credential, drep, redeemer \\ nil), to: CertificateHelper

  @doc delegate_to: {CertificateHelper, :delegate_stake_and_vote, 5}
  defdelegate delegate_stake_and_vote(
                builder,
                credential,
                drep,
                stake_pool_key_hash,
                redeemer \\ nil
              ),
              to: CertificateHelper

  def build_tx(cfg, opts \\ [])
  def build_tx(%__MODULE__{errors: [_ | _]} = cfg, _opts), do: {:error, cfg.errors}

  def build_tx(%__MODULE__{} = cfg, opts) do
    final_cfg = TxConfig.__setup(cfg.config, opts) |> TxConfig.__init()

    collateral_inputs = opts[:collateral_inputs] || []
    wallet_inputs = maybe(opts[:wallet_utxos], fn -> load_wallet_utxos(final_cfg) end)

    ref_inputs = Enum.uniq_by(cfg.ref_inputs, & &1.output_reference)
    inputs = Enum.uniq_by(cfg.inputs, & &1.output_reference)

    with :ok <- check_mint_balanced(cfg) do
      %__MODULE__{
        cfg
        | config: final_cfg,
          inputs: inputs,
          ref_inputs: ref_inputs,
          used_scripts: MapSet.to_list(cfg.used_scripts),
          certificates: Enum.reverse(cfg.certificates)
      }
      |> Internal.process_build_tx(wallet_inputs, collateral_inputs)
    end
  end

  def build_tx!(%__MODULE__{} = cfg, opts \\ []) do
    case build_tx(cfg, opts) do
      {:ok, tx} ->
        tx

      {:error, errors} ->
        raise inspect(errors)
    end
  end

  defp check_mint_balanced(%__MODULE__{mints: m}) when m == %{}, do: :ok

  defp check_mint_balanced(%__MODULE__{mints: mints, outputs: outputs}) do
    left_over_mint =
      Enum.reduce_while(outputs, mints, fn o, acc ->
        if Asset.only_positive(acc) == %{},
          do: {:halt, acc},
          else: {:cont, Asset.diff(o.value, acc)}
      end)

    if Asset.only_positive(left_over_mint) == %{},
      do: :ok,
      else:
        {:error,
         "No Output Found with Minting Policies: #{Enum.join(Map.keys(left_over_mint), ", ")}"}
  end

  defp load_wallet_utxos(%TxConfig{} = cfg) do
    addresses =
      if is_list(cfg.wallet_address),
        do: cfg.wallet_address,
        else: [cfg.wallet_address]

    cfg.provider.utxos_at(addresses)
  end

  def sign_tx(%Transaction{witnesses: %Witness{} = witness} = tx, signers)
      when is_list(signers) do
    tx_hash = Transaction.tx_id(tx) |> Base.decode16!(case: :mixed)

    new_vkey_witness =
      Enum.reduce(signers, MapSet.new(witness.vkey_witness), fn sk, acc ->
        signing_key = if is_binary(sk), do: Key.from_bech32(sk), else: {:ok, sk}

        case signing_key do
          {:ok, key} ->
            MapSet.put(acc, %VkeyWitness{
              vkey: Key.public_key(key),
              signature: Key.sign(key, tx_hash)
            })

          _ ->
            acc
        end
      end)

    %Transaction{
      tx
      | witnesses: %Witness{witness | vkey_witness: MapSet.to_list(new_vkey_witness)}
    }
  end

  def sign_tx(%Transaction{} = tx, signer), do: sign_tx(tx, [signer])

  def sign_tx_with_raw_extended_key(
        %Transaction{witnesses: %Witness{vkey_witness: vkey_witness} = witness} = tx,
        raw_extended_key
      )
      when is_binary(raw_extended_key) do
    tx_hash = Transaction.tx_id(tx) |> Base.decode16!(case: :mixed)

    new_vkey_witness =
      MapSet.new(vkey_witness)
      |> MapSet.put(%VkeyWitness{
        vkey: Key.public_key(raw_extended_key),
        signature: Key.sign(raw_extended_key, tx_hash)
      })

    %Transaction{
      tx
      | witnesses: %Witness{witness | vkey_witness: MapSet.to_list(new_vkey_witness)}
    }
  end

  def submit_tx(%Transaction{} = signed_tx) do
    with {:ok, provider} <- Provider.get_submitter() do
      submit_tx(signed_tx, provider)
    end
  end

  def submit_tx(%Transaction{} = signed_tx, provider) do
    provider.submit_tx(signed_tx)
  end
end
