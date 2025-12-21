defmodule Sutra.Provider.Kupogmios do
  @moduledoc """
    Kupo & Ogmios Provider implementation.
  """
  @behaviour Sutra.Provider

  alias Sutra.Provider.Kupogmios.Client
  alias Sutra.Cardano.Transaction
  alias Sutra.Data.Cbor
  alias Sutra.SlotConfig

  defp fetch_env(key), do: Application.get_env(:sutra, :kupogmios)[key]

  defp clients do
    Client.new(kupo_url: fetch_env(:kupo_url), ogmios_url: fetch_env(:ogmios_url))
  end

  @impl true
  def network, do: fetch_env(:network)

  @impl true
  def utxos_at_addresses(addresses) do
    clients()
    |> Client.utxos_at_addresses(addresses)
  end

  @impl true
  def utxos_at_tx_refs(refs) do
    clients()
    |> Client.utxos_at_tx_refs(refs)
  end

  @impl true
  def datum_of(_datum_hashes) do
    %{}
  end

  @impl true
  def protocol_params do
    clients()
    |> Client.protocol_params()
  end

  @impl true
  def slot_config do
    case network() do
      n when n in [:mainnet, :preprod, :preview] ->
        SlotConfig.fetch_slot_config(n)

      _ ->
        fetch_env(:slot_config)
    end
  end

  @impl true
  def submit_tx(tx_cbor) when is_binary(tx_cbor) do
    clients()
    |> Client.submit_tx(tx_cbor)
  end

  def submit_tx(%Transaction{} = tx) do
    Transaction.to_cbor(tx)
    |> Cbor.encode_hex()
    |> submit_tx()
  end

  @impl true
  def tx_cbor(_) do
    raise "tx_cbor callback not implemented in Sutra.Provider.Kupogmios"
  end
end
