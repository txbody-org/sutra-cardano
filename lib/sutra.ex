defmodule Sutra do
  @moduledoc """
  Sutra: The User-Friendly Component-Based Cardano SDK.

  Sutra is an Elixir-based SDK designed to simplify interactions with the Cardano blockchain. It abstracts complex transaction logic into composable building blocks, making it easy to build, sign, and submit transactions.

  ## Key Features

  *   **Composable API**: Build transactions step-by-step using a pipeline-based approach.
  *   **Provider Agnostic**: Works seamlessly with different providers (Blockfrost, Kupo/Ogmios, Maestro).
  *   **Plutus Support**: First-class support for Plutus scripts (V1, V2, V3), inline datums, and referencing scripts.

  ## Getting Started

  This module serves as the main entry point, delegating to `Sutra.Cardano.Transaction.TxBuilder`.

  ```elixir
  import Sutra

  # 1. Create a new transaction
  tx =
    new_tx()
    |> use_provider(MyProvider)
    |> add_input(utxos)
    |> add_output(friend_address, 10_000_000)

  # 2. Build and Sign
  signed_tx =
    tx
    |> build_tx!()
    |> sign_tx(private_key)

  # 3. Submit
  submit_tx(signed_tx)
  ```
  """
  alias Sutra.Cardano.Transaction.TxBuilder

  @doc delegate_to: {TxBuilder, :new_tx, 0}
  defdelegate new_tx(), to: TxBuilder

  @doc delegate_to: {TxBuilder, :use_provider, 2}
  defdelegate use_provider(builder, provider), to: TxBuilder

  @doc delegate_to: {TxBuilder, :set_protocol_params, 2}
  defdelegate set_protocol_params(builder, params), to: TxBuilder

  @doc delegate_to: {TxBuilder, :evaluate_provider_uplc, 2}
  defdelegate evaluate_provider_uplc(builder, evaluate \\ true), to: TxBuilder

  @doc delegate_to: {TxBuilder, :set_wallet_address, 2}
  defdelegate set_wallet_address(builder, address), to: TxBuilder

  @doc delegate_to: {TxBuilder, :set_change_address, 3}
  defdelegate set_change_address(builder, address, datum \\ nil), to: TxBuilder

  @doc delegate_to: {TxBuilder, :add_input, 3}
  defdelegate add_input(builder, inputs, opts \\ []), to: TxBuilder

  @doc delegate_to: {TxBuilder, :add_reference_inputs, 2}
  defdelegate add_reference_inputs(builder, inputs), to: TxBuilder

  @doc delegate_to: {TxBuilder, :add_output, 2}
  defdelegate add_output(builder, output), to: TxBuilder

  @doc delegate_to: {TxBuilder, :add_output, 4}
  defdelegate add_output(builder, address, assets, datum \\ nil), to: TxBuilder

  @doc delegate_to: {TxBuilder, :mint_asset, 5}
  defdelegate mint_asset(builder, policy_id, assets, policy, redeemer \\ nil), to: TxBuilder

  @doc delegate_to: {TxBuilder, :deploy_script, 3}
  defdelegate deploy_script(builder, address, script), to: TxBuilder

  @doc delegate_to: {TxBuilder, :add_signer, 2}
  defdelegate add_signer(builder, signer), to: TxBuilder

  @doc delegate_to: {TxBuilder, :attach_datum, 2}
  defdelegate attach_datum(builder, datum), to: TxBuilder

  @doc delegate_to: {TxBuilder, :attach_metadata, 3}
  defdelegate attach_metadata(builder, label, metadata), to: TxBuilder

  @doc delegate_to: {TxBuilder, :valid_from, 2}
  defdelegate valid_from(builder, time), to: TxBuilder

  @doc delegate_to: {TxBuilder, :valid_to, 2}
  defdelegate valid_to(builder, time), to: TxBuilder

  @doc delegate_to: {TxBuilder, :set_change_datum, 2}
  defdelegate set_change_datum(builder, datum), to: TxBuilder

  @doc delegate_to: {TxBuilder, :withdraw_stake, 3}
  defdelegate withdraw_stake(builder, credential, amount), to: TxBuilder

  @doc delegate_to: {TxBuilder, :withdraw_stake, 4}
  defdelegate withdraw_stake(builder, credential, redeemer, amount), to: TxBuilder

  @doc delegate_to: {TxBuilder, :register_stake_credential, 3}
  defdelegate register_stake_credential(builder, credential, redeemer \\ nil), to: TxBuilder

  @doc delegate_to: {TxBuilder, :delegate_vote, 4}
  defdelegate delegate_vote(builder, credential, drep, redeemer \\ nil), to: TxBuilder

  @doc delegate_to: {TxBuilder, :delegate_stake_and_vote, 5}
  defdelegate delegate_stake_and_vote(
                builder,
                credential,
                drep,
                stake_pool_key_hash,
                redeemer \\ nil
              ),
              to: TxBuilder

  @doc delegate_to: {TxBuilder, :build_tx, 2}
  defdelegate build_tx(builder, opts \\ []), to: TxBuilder

  @doc delegate_to: {TxBuilder, :build_tx!, 2}
  defdelegate build_tx!(builder, opts \\ []), to: TxBuilder

  @doc delegate_to: {TxBuilder, :sign_tx, 2}
  defdelegate sign_tx(builder, signers), to: TxBuilder

  @doc delegate_to: {TxBuilder, :sign_tx_with_raw_extended_key, 2}
  defdelegate sign_tx_with_raw_extended_key(builder, key), to: TxBuilder

  @doc delegate_to: {TxBuilder, :submit_tx, 1}
  defdelegate submit_tx(tx), to: TxBuilder

  @doc delegate_to: {TxBuilder, :submit_tx, 2}
  defdelegate submit_tx(tx, provider), to: TxBuilder
end
