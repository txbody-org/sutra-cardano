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
    Fetch datum data from datum Hash
  """
  @callback datum_of([binary()]) :: %{binary() => binary()}

  @doc """
    Submit Tx
  """
  @callback submit_tx(tx :: Transaction.t() | binary()) :: binary()

  def provider?(mod) do
    case mod.__info__(:attributes)[:behaviour] do
      v when is_list(v) -> Enum.member?(v, __MODULE__)
      _ -> false
    end
  end

  def get_provider(provider_type) do
    provider =
      case Application.get_env(:sutra, :provider) do
        v when is_list(v) -> v[provider_type]
        mod -> mod
      end

    if provider?(provider), do: {:ok, provider}, else: {:error, "Provider Not found"}
  end

  def get_fetcher, do: get_provider(:fetch_with)

  def get_submitter, do: get_provider(:submit_with)
end
