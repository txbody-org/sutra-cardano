defmodule Sutra.Provider do
  @moduledoc """
    data provider for cardano
  """
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig

  @doc """
    Returns Utxos At list of Address.

    To resolve datum we can pass `resolve_datum: true` as options
  """
  @callback utxos_at(addresses :: [Address.bech_32() | Address.t()]) ::
              [Transaction.input()]

  @doc """
    Query Utxos at list of OutputReference
  """
  @callback utxos_at_refs(refs :: [OutputReference.t() | String.t()]) :: [Transaction.input()]

  @doc """
    Query Protocol params
  """
  @callback protocol_params() :: ProtocolParams.t()

  @doc """
    Query Slot config
  """
  @callback slot_config() :: SlotConfig.t()

  @doc """
    get Network type
  """
  @callback network() :: Address.network()

  @doc """
    Submit Tx
  """
  @callback submit_tx(tx :: Transaction.t() | binary()) :: binary()

  def provider?(mod),
    do:
      function_exported?(mod, :utxos_at, 1) and
        function_exported?(mod, :utxos_at_refs, 1) and
        function_exported?(mod, :protocol_params, 0) and
        function_exported?(mod, :slot_config, 0) and
        function_exported?(mod, :network, 0) and function_exported?(mod, :submit_tx, 1)
end
