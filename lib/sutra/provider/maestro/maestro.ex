defmodule Sutra.Provider.Maestro do
  @moduledoc """
    Maestro Provider implementation.
  """
  @behaviour Sutra.Provider

  alias Sutra.Provider.Maestro.Client
  alias Sutra.Cardano.Transaction
  alias Sutra.SlotConfig

  defp fetch_env(key), do: Application.get_env(:sutra, :maestro)[key]

  defp client do
    Client.new(
      api_key: fetch_env(:api_key),
      network: fetch_env(:network),
      base_url: fetch_env(:base_url)
    )
  end

  @impl true
  def network, do: fetch_env(:network) || :mainnet

  @impl true
  def utxos_at_addresses(addresses) do
    client()
    |> Client.utxos_at_addresses(addresses)
  end

  @impl true
  def utxos_at_tx_refs(refs) do
    client()
    |> Client.utxos_at_tx_refs(refs)
  end

  @impl true
  def datum_of(_datum_hashes) do
    # Maestro deprecated datum lookup by hash.
    # Datums are resolved during UTXO/TxO lookup.
    %{}
  end

  @impl true
  def protocol_params do
    client()
    |> Client.protocol_params()
  end

  @impl true
  def slot_config do
    network()
    |> SlotConfig.fetch_slot_config()
  end

  @impl true
  def submit_tx(cbor) when is_binary(cbor) do
    client()
    |> Client.submit_tx(cbor)
  end

  def submit_tx(%Transaction{} = tx) do
    Transaction.to_cbor(tx)
    |> CBOR.encode()
    |> submit_tx()
  end

  @impl true
  def evaluate_tx(cbor) do
    client()
    |> Client.evaluate_tx(cbor)
  end

  @impl true
  def tx_cbor(tx_hashes) do
    client()
    |> Client.tx_cbor(tx_hashes)
  end
end
