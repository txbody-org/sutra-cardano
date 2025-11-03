defmodule Sutra.Cardano.Transaction.TxBuilder.CertificateHelper do
  @moduledoc false

  require Sutra.Cardano.Script
  alias Sutra.Utils
  alias Sutra.Cardano.Common.StakePool
  alias Sutra.Cardano.Transaction.Certificate.StakeVoteRegDelegCert
  alias Sutra.Cardano.Transaction.Certificate.VoteDelegCert
  alias Sutra.Cardano.Common.Drep
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Certificate.RegisterCert
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Transaction.TxBuilder

  @min_ada_for_stake_reg 2_000_000

  @doc """
  Register a stake credential 

    ## Parameters
      * `tx_builder` - The `%TxBuilder{}` struct representing current transaction
      * `credential` - The Credential to register Stake. either `%Address{}` with vkey stake credential, `%Scrip{}` Plutus Script or NativeScript
      * `redeemer`   - The redeemer if trying to Register stake for Plutus Script


    ## Examples
      iex> new_tx() |>  register_stake_credential(%Address{})
      %TxBuilder{}

      iex> new_tx() |> register_stake_credential(NativeScript.from_json(%{}))
      %TxBuilder{}

      iex> new_tx() |> register_stake_credential(%Script{}, redeemer_data)
      %TxBuilder{}
  """

  def register_stake_credential(%TxBuilder{certificates: certs} = builder, cred, redeemer \\ nil) do
    redeemer = if Script.is_plutus_script(cred), do: redeemer, else: nil

    cert = %RegisterCert{
      stake_credential: prepare_credential(cred),
      coin: Asset.from_lovelace(@min_ada_for_stake_reg)
    }

    with_cert_handler(builder, cred, fn %TxBuilder{} = new_builder ->
      %TxBuilder{
        new_builder
        | certificates: [{cert, redeemer} | certs],
          total_deposit: Asset.add(builder.total_deposit, "lovelace", @min_ada_for_stake_reg)
      }
    end)
  end

  @doc """
  Delegates Vote to Drep

    ## Parameters
      * `tx_builder` - The `%TxBuilder{}` struct representing current transaction
      * `credential` - The Credential to register Stake. either `%Address{}` with vkey stake credential, `%Scrip{}` Plutus Script or NativeScript
      * `drep`       - The `%Drep{}` 
      * `redeemer`   - The redeemer if trying to Register stake for Plutus Script


    ## Examples
      iex> new_tx() |>  delegate_vote(%Address{}, %Drep{})
      %TxBuilder{}

      iex> new_tx() |> delegate_vote(NativeScript.from_json(%{}), %Drep{})
      %TxBuilder{}

      iex> new_tx() |> delegate_vote(%Script{}, %Drep{}, redeemer_data)
      %TxBuilder{}
  """

  def delegate_vote(
        %TxBuilder{} = builder,
        cred,
        %Drep{} = drep,
        redeemer \\ nil
      ) do
    cert = %VoteDelegCert{
      stake_credential: prepare_credential(cred),
      drep: drep
    }

    with_cert_handler(builder, cred, fn %TxBuilder{} = new_builder ->
      %TxBuilder{new_builder | certificates: [{cert, redeemer} | builder.certificates]}
    end)
  end

  @doc """
  Delegates Stake to StakePool and Vote to Drep in single Transaction

    ## Parameters
      * `tx_builder` - The `%TxBuilder{}` struct representing current transaction
      * `credential` - The Credential to register Stake. either `%Address{}` with vkey stake credential, `%Scrip{}` Plutus Script or NativeScript
      * `drep`       - The `%Drep{}` 
      * `stake pool keyhash` - The StakePool Key Hash
      * `redeemer`   - The redeemer if trying to Register stake for Plutus Script


    ## Examples

      iex> {:ok, pool_key_hash = StakePool.from_bech32("pool1....")}
      iex> new_tx() |>  delegate_stake_and_vote(%Address{}, %Drep{}, pool_key_hash)
      %TxBuilder{}

      iex> new_tx() |> delegate_stake_and_vote(NativeScript.from_json(%{}), %Drep{}, pool_key_hash)
      %TxBuilder{}


      iex> new_tx() |> delegate_stake_and_vote(%Script{}, %Drep{}, "pool1....", redeemer_data)
      %TxBuilder{}
      
      # we can also pass pool Bech32
      iex> new_tx() |> delegate_stake_and_vote(%Script{}, %Drep{}, "pool1....", redeemer_data)
      %TxBuilder{}
  """

  def delegate_stake_and_vote(
        %TxBuilder{} = builder,
        cred,
        %Drep{} = drep,
        pool_id,
        redeemer \\ nil
      ) do
    pool_key_hash = Utils.ok_or(StakePool.from_bech32(pool_id), pool_id)

    cert = %StakeVoteRegDelegCert{
      stake_credential: prepare_credential(cred),
      pool_keyhash: pool_key_hash,
      drep: drep,
      deposit: Asset.from_lovelace(@min_ada_for_stake_reg)
    }

    with_cert_handler(builder, cred, fn %TxBuilder{} = updated_builder ->
      %TxBuilder{
        updated_builder
        | certificates: [{cert, redeemer} | builder.certificates],
          total_deposit: Asset.add(builder.total_deposit, "lovelace", @min_ada_for_stake_reg)
      }
    end)
  end

  defp prepare_credential(%Address{
         stake_credential: %Credential{credential_type: :vkey, hash: hash} = stake_cred
       })
       when is_binary(hash), do: stake_cred

  defp prepare_credential(script) when Script.is_script(script),
    do: %Credential{credential_type: :script, hash: Script.hash_script(script)}

  defp with_cert_handler(
         %TxBuilder{} = cfg,
         %Address{stake_credential: %Credential{credential_type: :vkey, hash: stake_key_hash}},
         handle
       )
       when is_function(handle, 1) do
    new_cfg = %TxBuilder{
      cfg
      | required_signers: MapSet.put(cfg.required_signers, stake_key_hash)
    }

    handle.(new_cfg)
  end

  defp with_cert_handler(
         %TxBuilder{} = cfg,
         script,
         handle
       )
       when Script.is_script(script) do
    script_type = if Script.is_native_script(script), do: :native, else: script.script_type

    new_cfg =
      %TxBuilder{
        cfg
        | script_lookup: Map.put_new(cfg.script_lookup, Script.hash_script(script), script),
          used_scripts: MapSet.put(cfg.used_scripts, script_type)
      }

    handle.(new_cfg)
  end
end
