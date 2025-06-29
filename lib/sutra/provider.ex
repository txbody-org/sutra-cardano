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

  def utxos_at(addresses) do
    get_provider!().utxos_at(addresses)
  end

  def utxos_at_refs(refs) do
    get_provider!().utxos_at_refs(refs)
  end

  def protocol_params do
    get_provider!().protocol_params()
  end

  def slot_config do
    get_provider!().slot_config()
  end

  def network do
    get_provider!().network()
  end

  def datum_of(datum_hashes) do
    get_provider!().datum_of(datum_hashes)
  end

  def provider?(mod) do
    case mod.__info__(:attributes)[:behaviour] do
      v when is_list(v) -> Enum.member?(v, __MODULE__)
      _ -> false
    end
  end

  def get_provider(provider_type \\ nil) do
    provider =
      case Application.get_env(:sutra, :provider) do
        v when is_list(v) -> v[provider_type]
        mod -> mod
      end

    if provider?(provider), do: {:ok, provider}, else: {:error, "Provider Not found"}
  end

  @doc """
    Get provider module, if not found raise error
  """
  @spec get_provider!(atom() | nil) :: module()
  def get_provider!(provider_type \\ nil) do
    case get_provider(provider_type) do
      {:ok, mod} -> mod
      {:error, _} -> raise "Provider Not found"
    end
  end

  def get_fetcher, do: get_provider(:fetch_with)

  def get_submitter, do: get_provider(:submit_with)
end
