defmodule Sutra.Provider do
  @moduledoc """
    data provider for cardano
  """
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Common.ExecutionUnits
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig

  @doc """
    Returns Utxos At list of Address.

    To resolve datum we can pass `resolve_datum: true` as options
  """
  @callback utxos_at_addresses(addresses :: [Address.bech_32() | Address.t()]) ::
              [Transaction.input()]

  @doc """
    Query Utxos at list of OutputReference
  """
  @callback utxos_at_tx_refs(refs :: [OutputReference.t() | String.t()]) :: [Transaction.input()]

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

  @doc """
    Fetch Tx cbor by tx hash
  """

  @callback tx_cbor([txhash :: binary()]) :: %{(tx_hash :: binary()) => cbor :: binary()}

  @doc """
    Evaluate Tx cbor
  """
  @callback evaluate_tx(cbor :: binary()) ::
              {:ok, ExecutionUnits.t()}
              | {:ok, map()}
              | {:ok, [any()]}
              | {:error, String.t()}
  @optional_callbacks evaluate_tx: 1

  def utxos_at_addresses(addresses) do
    get_provider!().utxos_at_addresses(addresses)
  end

  def utxos_at_tx_refs(refs) do
    get_provider!().utxos_at_tx_refs(refs)
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

  def tx_cbor(tx_hash) do
    get_provider!().tx_cbor(tx_hash)
  end

  def evaluate_tx(tx_cbor) do
    provider = get_provider!()

    if function_exported?(provider, :evaluate_tx, 1) do
      provider.evaluate_tx(tx_cbor)
    else
      {:error, "Provider does not support evaluate_tx"}
    end
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

  @doc """
  Waits for transaction to be confirmed on chain by polling for its 0-index UTxO.
  Function sleeps for 2s initially and backs off exponentially (1.5x) up to retry_count times.
  """
  def await_tx(tx_hash, retry_count \\ 10) do
    await_tx_impl(tx_hash, retry_count, 2000)
  end

  defp await_tx_impl(_tx_hash, 0, _delay), do: {:error, :timeout}

  defp await_tx_impl(tx_hash, retries, delay) do
    # Check if index 0 exists (heuristic)
    case utxos_at_tx_refs(["#{tx_hash}#0"]) do
      [_ | _] ->
        :ok

      _ ->
        Process.sleep(trunc(delay))
        await_tx_impl(tx_hash, retries - 1, min(delay * 2.5, 10_000))
    end
  end
end
