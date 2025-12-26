defmodule Sutra.Cardano.Transaction.TxBuilder do
  @moduledoc """
  A composable builder for constructing Cardano Transactions.

  `TxBuilder` provides a pipeline-based API to build transactions step-by-step. It handles:
  - Adding inputs (spending UTxOs)
  - Adding outputs (sending payments)
  - Minting/burning assets
  - Managing witnesses (signatures, scripts)
  - Handling collateral and fees
  - Balancing the transaction (calculating change)

  ## Example Usage

  ```elixir
  alias Sutra.Cardano.Transaction.TxBuilder
  import Sutra.Cardano.Transaction.TxBuilder

  new_tx()
  |> add_input(utxos_to_spend)
  |> add_output(receiver_address, 10_000_000)
  |> build_tx!(wallet_address: change_address)
  |> sign_tx(signing_key)
  |> submit_tx()
  ```
  """
  require Sutra.Cardano.Script
  require Sutra.Data.Plutus

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
  Initialize a new empty `TxBuilder`.

  ## Examples

      iex> new_tx()
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def new_tx do
    %__MODULE__{
      config: %TxConfig{evaluate_provider_uplc: false}
    }
  end

  @doc """
  Overrides the default provider for the transaction builder.

  ## Examples

      iex> new_tx() |> use_provider(Sutra.Provider.Koios)
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def use_provider(%__MODULE__{config: cfg} = builder, provider) when not is_nil(provider) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :provider, provider)}
  end

  @doc """
  Sets custom Protocol Parameters for transaction building.

  Useful when you want to override the provider's fetched protocol parameters or use specific values for fee calculation.

  ## Examples

      iex> params = %Sutra.ProtocolParams{min_fee_a: 44, min_fee_b: 155381}
      iex> new_tx() |> set_protocol_params(params)
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def set_protocol_params(%__MODULE__{config: cfg} = builder, %ProtocolParams{} = protocol_params) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :protocol_params, protocol_params)}
  end

  @doc """
  Toggles runtime UPLC script evaluation by the provider during transaction building.

  When set to `true`, the builder will send the transaction to the configured provider (e.g., Blockfrost, Maestro)
  to evaluate script execution units (ExUnits) and validate script logic before finalizing the transaction.

  This is highly recommended for transactions involving Plutus scripts to ensure they will pass on-chain validation
  and to accurately calculate execution fees.

  Defaults to `false`.

  ## Examples

      iex> new_tx() |> evaluate_provider_uplc(true)
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def evaluate_provider_uplc(%__MODULE__{config: cfg} = builder, evaluate \\ true) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :evaluate_provider_uplc, evaluate)}
  end

  @doc """
  Sets the wallet address(es) to be used for the transaction.

  This is primarily used to:
  1. Fetch UTxOs for balancing (if `wallet_utxos` is not provided in `build_tx!`).
  2. Determine the change address (if `set_change_address` is not explicitly called).

  ## Examples

      iex> address = Sutra.Cardano.Address.from_bech32("addr_test1...")
      iex> new_tx() |> set_wallet_address(address)
      %Sutra.Cardano.Transaction.TxBuilder{}

      iex> addresses = [address1, address2]
      iex> new_tx() |> set_wallet_address(addresses)
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def set_wallet_address(%__MODULE__{config: cfg} = builder, %Address{} = address) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :wallet_address, [address])}
  end

  def set_wallet_address(%__MODULE__{config: cfg} = builder, addresses) when is_list(addresses) do
    %__MODULE__{builder | config: TxConfig.__set_cfg(cfg, :wallet_address, addresses)}
  end

  @doc """
  Sets a custom change address for the transaction.

  If not set, the first address from `set_wallet_address` is used as the change address.
  You can also specify a datum to be attached to the change output.

  ## Examples

      iex> address = Sutra.Cardano.Address.from_bech32("addr_test1...")
      iex> new_tx() |> set_change_address(address)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Change Address with datum
      iex> datum = %Sutra.Cardano.Transaction.Datum{kind: :inline_datum, value: "data"}
      iex> new_tx() |> set_change_address(address, {:inline_datum, datum})
      %Sutra.Cardano.Transaction.TxBuilder{}

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
  Adds Inputs (UTxOs) to the transaction.

  ## Parameters

  - `builder`: The `TxBuilder` instance.
  - `inputs`: A list of `%Sutra.Cardano.Transaction.Input{}` to spend.
  - `opts`: options for spending inputs.

  ## Options

  - `witness`: The witness for the input.
    - `:vkey_witness` (default) - For standard wallet inputs (P2PKH).
    - `%Script{}` or `%NativeScript{}` - The spending script itself.
    - `%Input{}` - The reference input containing the spending script (CIP-33).
    - `:ref_inputs` - Indicates the script is provided via `add_reference_inputs/2`.
  - `redeemer`: The redeemer data (required for script spending).
  - `datum`: Explicit datum info (e.g., `{:datum_hash, data}`) if the UTxO from provider doesn't contain it.

  ## Examples

      # Simple wallet spend
      iex> new_tx() |> add_input(wallet_inputs)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Spending from a Native Script
      iex> new_tx() |> add_input(native_script_inputs, witness: native_script)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Spending from a Plutus Script
      iex> new_tx() |> add_input(script_inputs, witness: script, redeemer: redeemer_data)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Spending using a Reference Script on-chain
      iex> new_tx() |> add_input(script_inputs, witness: ref_script_utxo, redeemer: redeemer_data)
      %Sutra.Cardano.Transaction.TxBuilder{}

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

  @doc """
  Adds Reference Inputs to the transaction (CIP-31).

  Reference incoming inputs allow reading from UTxOs without spending them.
  Commonly used for:
  - Reference scripts (CIP-33) to use scripts without including them in witness set.
  - Using Inline Datums (CIP-32) from reference inputs.

  ## Examples

      iex> add_reference_inputs(new_tx(), [script_ref_utxo])
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def add_reference_inputs(%__MODULE__{} = builder, [%Input{} | _] = inputs) do
    new_script_lookup =
      Enum.reduce(inputs, builder.script_lookup, fn %Input{} = input, acc ->
        if Script.script?(input.output.reference_script),
          do: Map.put(acc, Script.hash_script(input.output.reference_script), input),
          else: acc
      end)

    %__MODULE__{
      builder
      | ref_inputs: builder.ref_inputs ++ inputs,
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
  Adds an Output to the transaction.

  You can pass a constructed `%Output{}` struct or use the helper with address, value, and optional datum.

  ## Examples

      iex> output = %Sutra.Cardano.Transaction.Output{address: address, value: %{"lovelace" => 100}}
      iex> add_output(%TxBuilder{}, output)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Simple payment (Lovelace only)
      iex> add_output(%TxBuilder{}, address, 5_000_000)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Payment with Native Assets
      iex> add_output(%TxBuilder{}, address, %{"lovelace" => 2_000_000, "policy_id" => %{"token" => 10}})
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Output with inline datum
      iex> add_output(%TxBuilder{}, address, 2_000_000, {:inline_datum, datum_data})
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Output with datum hash
      iex> add_output(%TxBuilder{}, address, 2_000_000, {:datum_hash, datum_data})
      %Sutra.Cardano.Transaction.TxBuilder{}

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
    hashed_datum = Datum.calculate_datum_hash(raw_data)

    {Data.decode!(raw_data), Datum.datum_hash(hashed_datum)}
  end

  defp extract_datum(_), do: {nil, Datum.no_datum()}

  @doc """
  Mints or Burns assets.

  ## Parameters

  - `builder`: The `TxBuilder` instance.
  - `policy_id`: Hex string of the minting policy ID.
  - `assets`: A map of asset names to quantities (e.g. `%{"tkn" => 100}`). Negative quantities mean burning.
  - `minting_policy`: The witness for minting.
    - `%Script{}` or `%NativeScript{}`
    - `:ref_inputs` (if policy script is in reference inputs)
  - `redeemer`: Redeemer data (required for Plutus minting).

  ## Examples

      # Minting with Native Script
      iex> mint_asset(%TxBuilder{}, policy_id, %{"tkn" => 100}, native_script)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Burning with Plutus Script
      iex> mint_asset(%TxBuilder{}, policy_id, %{"tkn" => -100}, plutus_script, redeemer)
      %Sutra.Cardano.Transaction.TxBuilder{}

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
  Deploys a script to the blockchain (Create reference script output).

  Creates an output at the specified address containing the script as a reference script.
  The output will contain the minimum required Ada.

  ## Parameters

  - `builder`: The `TxBuilder` instance.
  - `out_addr`: The Address where the utility output will be sent.
  - `script`: The `%Script{}` or `%NativeScript{}` to be attached.

  ## Examples

      iex> deploy_script(new_tx(), address, plutus_script)
      %Sutra.Cardano.Transaction.TxBuilder{}

      iex> deploy_script(new_tx(), address, native_script)
      %Sutra.Cardano.Transaction.TxBuilder{}

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
  Explicitly adds a required signer to the transaction body.

  This is useful when the transaction needs to be signed by a key that isn't necessarily
  spending a UTxO (e.g., for governance actions or special script requirements).

  ## Examples

      iex> add_signer(new_tx(), address)
      %Sutra.Cardano.Transaction.TxBuilder{}

      iex> add_signer(new_tx(), "pubkey_hash_hex")
      %Sutra.Cardano.Transaction.TxBuilder{}

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
  Explicitly adds datum to the witness set (lookup map).

  This is useful when you want to include datum in the transaction body without embedding it in an output,
  usually for script validation purposes.

  ## Examples

      iex> attach_datum(new_tx(), %Sutra.Data.Plutus.Constr{tag: 121, fields: []})
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def attach_datum(%__MODULE__{} = cfg, datum) do
    encoded_datum = Data.encode(datum)
    datum_hash = Datum.calculate_datum_hash(encoded_datum)

    %__MODULE__{
      cfg
      | plutus_data:
          Map.put_new(
            cfg.plutus_data,
            datum_hash,
            Data.decode!(encoded_datum)
          )
    }
  end

  @doc """
  Attaches JSON metadata to the transaction.

  ## Parameters

  - `builder`: The `TxBuilder` instance.
  - `label`: Integer label for the metadata (e.g., 721 for NFTs).
  - `metadata`: The metadata content (Map, List, String, Integer, etc.).

  ## Examples

      iex> attach_metadata(new_tx(), 721, %{"policy" => ...})
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
  def attach_metadata(%__MODULE__{} = builder, label, metadata)
      when not is_nil(metadata) and is_integer(label) do
    %__MODULE__{builder | metadata: Map.put(%{}, label, metadata)}
  end

  @doc """
  Sets the transaction validity start interval.

  ## Examples

      iex> valid_from(new_tx(), DateTime.utc_now())
      %Sutra.Cardano.Transaction.TxBuilder{}

      iex> valid_from(new_tx(), 1678900000000)
      %Sutra.Cardano.Transaction.TxBuilder{}
  """
  def valid_from(%__MODULE__{} = cfg, %DateTime{} = dt) do
    %__MODULE__{cfg | valid_from: DateTime.to_unix(dt, :millisecond)}
  end

  def valid_from(%__MODULE__{} = cfg, timestamp) when is_integer(timestamp),
    do: %__MODULE__{cfg | valid_from: timestamp}

  @doc """
  Sets the transaction validity end interval (TTL).

  ## Examples

      iex> valid_to(new_tx(), DateTime.utc_now() |> DateTime.add(300, :second))
      %Sutra.Cardano.Transaction.TxBuilder{}

      iex> valid_to(new_tx(), 1678900000000)
      %Sutra.Cardano.Transaction.TxBuilder{}
  """

  def valid_to(%__MODULE__{} = cfg, %DateTime{} = dt) do
    %__MODULE__{cfg | valid_to: DateTime.to_unix(dt, :millisecond)}
  end

  def valid_to(%__MODULE__{} = cfg, timestamp) when is_integer(timestamp),
    do: %__MODULE__{cfg | valid_to: timestamp}

  @doc """
  Sets the datum to be used for the change output.

  If not set, the change output will not have a datum.

  ## Examples

      iex> set_change_datum(new_tx(), datum_data)
      %Sutra.Cardano.Transaction.TxBuilder{}
  """
  def set_change_datum(%__MODULE__{} = cfg, datum) when Plutus.is_plutus_data(datum) do
    %__MODULE__{cfg | config: TxConfig.__set_cfg(cfg.config, :change_datum, datum)}
  end

  @doc """
  Withdraws rewards from a stake address.

  ## Parameters

  - `builder`: The `TxBuilder` instance.
  - `stake_credential`: The stake address or credential to withdraw from.
  - `lovelace`: The amount to withdraw.
  - `redeemer`: (Optional) Redeemer if withdrawing from a script credential.

  ## Examples

      # Withdraw from key credential
      iex> withdraw_stake(new_tx(), stake_address, 500_000)
      %Sutra.Cardano.Transaction.TxBuilder{}

      # Withdraw from script credential
      iex> withdraw_stake(new_tx(), script, redeemer, 500_000)
      %Sutra.Cardano.Transaction.TxBuilder{}

  """
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

  @doc """
  Builds the transaction body.

  This function balances the transaction by:
  1. Fetching UTxOs from the wallet address (if not provided).
  2. Selecting necessary inputs to cover outputs and fees.
  3. Calculating fees and change.
  4. Evaluating script execution units (if `evaluate_provider_uplc` is enabled).

  ## Options

  - `wallet_utxos`: A list of `%Input{}` to be used for balancing. If not provided, they are fetched from the wallet address.
  - `collateral_inputs`: A list of `%Input{}` to be used as collateral (required for Plutus scripts).

  ## Examples

      iex> build_tx(builder)
      {:ok, %Sutra.Cardano.Transaction{}}

      iex> build_tx(builder, wallet_utxos: my_utxos)
      {:ok, %Sutra.Cardano.Transaction{}}

  """
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
          certificates: Enum.reverse(cfg.certificates),
          outputs: Enum.reverse(cfg.outputs)
      }
      |> Internal.process_build_tx(wallet_inputs, collateral_inputs)
    end
  end

  @doc """
  Same as `build_tx/2` but raises an exception on error.
  """
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

    cfg.provider.utxos_at_addresses(addresses)
  end

  @doc """
  Signs the transaction with the provided key(s).

  ## Parameters

  - `tx`: The `%Transaction{}` struct (usually result of `build_tx!`).
  - `signers`: A signing key (Bech32 string or key tuple) or a list of signing keys.

  ## Examples

      iex> sign_tx(tx, signing_key)
      %Sutra.Cardano.Transaction{}

  """
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

  @doc """
  Signs the transaction using a raw extended private key.

  This is useful when you have the raw private key bytes (e.g. from a derived child key or a generated keypair)
  and need to sign the transaction. The key can be a payment key or a stake key.

  ## Examples

      # Basic Usage with Hex String
      iex> sign_tx_with_raw_extended_key(tx, "5820...")
      %Sutra.Cardano.Transaction{}

      # Signing with derived keys from Sutra.Crypto.Key
      # `derive_child/3` returns an `%ExtendedKey{}` containing both payment and stake keys.
      iex> root_key = Sutra.Crypto.Key.generate_root_key("seed phrase ...")
      iex> {:ok, %ExtendedKey{} = key} = Sutra.Crypto.Key.derive_child(root_key, 0, 0)

      # Interact with the keys directly
      iex> tx = sign_tx_with_raw_extended_key(tx, key.payment_key)
      iex> tx = sign_tx_with_raw_extended_key(tx, key.stake_key)

  """
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

  @doc """
  Submits the signed transaction to the blockchain.

  If no provider is specified, it uses the globally configured submitter.

  ## Examples

      iex> submit_tx(signed_tx)
      {:ok, "tx_hash_hex"}

      iex> submit_tx(signed_tx, provider)
      {:ok, "tx_hash_hex"}

  """
  def submit_tx(%Transaction{} = signed_tx) do
    with {:ok, provider} <- Provider.get_submitter() do
      submit_tx(signed_tx, provider)
    end
  end

  def submit_tx(%Transaction{} = signed_tx, provider) do
    provider.submit_tx(signed_tx)
  end
end
