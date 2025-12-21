defmodule Sutra.Provider.Yaci do
  @moduledoc """
    Yaci Devkit Provider implementation.
  """
  @behaviour Sutra.Provider

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction
  alias Sutra.ProtocolParams
  alias Sutra.Provider.Yaci.Client
  alias Sutra.SlotConfig

  defp clients do
    config = Application.get_env(:sutra, :yaci, [])

    Client.new(
      general_api_url: config[:yaci_general_api_url] || "http://localhost:8080",
      admin_api_url: config[:yaci_admin_api_url] || "http://localhost:10000"
    )
  end

  @impl true
  def network, do: :testnet

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
  def datum_of(datum_hashes) do
    clients()
    |> Client.datum_of(datum_hashes)
  end

  @impl true
  def protocol_params do
    case Client.protocol_params(clients(), 3) do
      {:error, reason} -> raise reason
      protocol_params -> protocol_params
    end
  end

  @impl true
  def slot_config do
    yaci_cfg = Application.get_env(:sutra, :yaci) || []

    case yaci_cfg[:slot_config] do
      %SlotConfig{} = slot_cfg ->
        slot_cfg

      _ ->
        Client.slot_config(clients())
    end
  end

  @impl true
  def submit_tx(tx_cbor) when is_binary(tx_cbor) do
    clients()
    |> Client.submit_tx(tx_cbor)
  end

  def submit_tx(%Transaction{} = tx) do
    Transaction.to_cbor(tx)
    |> CBOR.encode()
    |> submit_tx()
  end

  @impl true
  def tx_cbor(_) do
    raise "tx_cbor callback not implemented in Sutra.Provider.Yaci"
  end

  # Extra convenience functions

  def topup(address, qty) when is_integer(qty) and is_binary(address) do
    Client.topup(clients(), address, qty)
  end

  def topup(%Address{} = addr, qty), do: Address.to_bech32(addr) |> topup(qty)

  def running? do
    case Client.protocol_params(clients(), 0) do
      %ProtocolParams{} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  def balance_of(address) when is_binary(address) do
    Client.balance_of(clients(), address)
  end

  def balance_of(%Address{} = addr), do: Address.to_bech32(addr) |> balance_of()

  def get_tx_info(tx_id) when is_binary(tx_id) do
    Client.get_tx_info(clients(), tx_id)
  end
end
