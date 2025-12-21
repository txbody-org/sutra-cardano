defmodule Sutra.Provider.Blockfrost do
  @moduledoc """
    Blockfrost Provider implementation.
  """
  @behaviour Sutra.Provider

  alias Sutra.Provider.Blockfrost.Client
  alias Sutra.Cardano.Transaction
  alias Sutra.SlotConfig
  alias Sutra.Cardano.Transaction.{Datum, Input, Output}
  alias Sutra.Data
  alias Sutra.Utils

  defp fetch_env(key), do: Application.get_env(:sutra, :blockfrost)[key]

  defp client do
    Client.new(
      project_id: fetch_env(:project_id),
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
    |> attach_datum_raw_to_utxos()
  end

  @impl true
  def utxos_at_tx_refs(refs) do
    client()
    |> Client.utxos_at_tx_refs(refs)
    |> attach_datum_raw_to_utxos()
  end

  @impl true
  def datum_of(datum_hashes) do
    client()
    |> Client.datum_of(datum_hashes)
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

  # Internal Logic

  defp attach_datum_raw_to_utxos(utxos) when is_list(utxos) do
    get_datum_hash = fn %Output{datum: %Datum{} = datum} ->
      if datum.kind == :datum_hash, do: datum.value, else: nil
    end

    datum_hashes =
      Enum.reduce(utxos, MapSet.new([]), fn %Input{output: %Output{} = o}, acc ->
        Utils.maybe(get_datum_hash.(o), acc, &MapSet.put(acc, &1))
      end)
      |> MapSet.to_list()
      |> datum_of()

    put_raw_datum = fn %Output{} = output ->
      Utils.maybe(get_datum_hash.(output), output, fn hash ->
        %Output{
          output
          | datum_raw: Utils.maybe(datum_hashes[hash], nil, &Data.decode!/1)
        }
      end)
    end

    if datum_hashes == %{},
      do: utxos,
      else:
        Enum.map(utxos, fn %Input{output: %Output{}} = input ->
          %Input{input | output: put_raw_datum.(input.output)}
        end)
  end
end
