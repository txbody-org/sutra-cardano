defmodule Sutra.Provider.Blockfrost.Client do
  @moduledoc """
    Client for Blockfrost API using Req.
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Transaction.{Datum, Input, Output, OutputReference}
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.ProtocolParams

  def new(opts \\ []) do
    project_id = opts[:project_id]
    network = opts[:network] || :mainnet

    base_url =
      opts[:base_url] ||
        case network do
          :mainnet -> "https://cardano-mainnet.blockfrost.io/api/v0"
          :preprod -> "https://cardano-preprod.blockfrost.io/api/v0"
          :preview -> "https://cardano-preview.blockfrost.io/api/v0"
          _ -> raise "Unsupported Blockfrost network: #{network}"
        end

    Req.new(
      base_url: base_url,
      headers: [
        {"project_id", project_id},
        {"accept", "application/json"},
        {"content-type", "application/json"}
      ]
    )
  end

  def utxos_at_addresses(client, addresses) do
    addresses
    |> Enum.map(fn addr ->
      addr_str = if is_binary(addr), do: addr, else: Address.to_bech32(addr)

      Task.async(fn ->
        Req.get!(client, url: "addresses/#{addr_str}/utxos").body
        |> Enum.map(&parse_utxo/1)
      end)
    end)
    |> Task.await_many(30_000)
    |> List.flatten()
  end

  def utxos_at_tx_refs(client, refs) do
    refs
    |> Enum.map(fn
      %OutputReference{transaction_id: tx_id, output_index: index} ->
        {tx_id, index}

      ref when is_binary(ref) ->
        [tx_id, index_str] = String.split(ref, "#")
        {tx_id, String.to_integer(index_str)}
    end)
    |> Enum.group_by(fn {tx_id, _} -> tx_id end, fn {_, index} -> index end)
    |> Enum.map(fn {tx_id, indices} ->
      Task.async(fn -> fetch_tx_utxos(client, tx_id, indices) end)
    end)
    |> Task.await_many(30_000)
    |> List.flatten()
  end

  def datum_of(client, datum_hashes) when is_list(datum_hashes) do
    datum_hashes
    |> Enum.map(fn hash ->
      Task.async(fn -> fetch_datum_cbor(client, hash) end)
    end)
    |> Task.await_many(30_000)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  def protocol_params(client) do
    Req.get!(client, url: "epochs/latest/parameters").body
    |> parse_protocol_params()
  end

  def submit_tx(client, cbor) do
    Req.post!(client,
      url: "tx/submit",
      body: cbor,
      headers: %{"content-type" => "application/cbor"}
    ).body
  end

  def evaluate_tx(client, cbor) do
    resp =
      Req.post!(client,
        url: "utils/txs/evaluate",
        body: cbor,
        headers: %{"content-type" => "application/cbor"}
      ).body

    # Blockfrost response might be directly the result or wrapper.
    case resp do
      %{"result" => %{"EvaluationResult" => result}} ->
        files =
          Enum.map(result, fn {k, v} ->
            {k, %ExecutionUnits{mem: v["memory"], step: v["steps"]}}
          end)
          |> Map.new()

        {:ok, files}

      %{"result" => %{"EvaluationFailure" => failure}} ->
        {:error, inspect(failure)}

      _ ->
        {:error, "Unknown evaluation error"}
    end
  end

  def tx_cbor(client, tx_hashes) do
    tx_hashes
    |> Enum.map(fn hash ->
      Task.async(fn -> fetch_tx_cbor(client, hash) end)
    end)
    |> Task.await_many(30_000)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp fetch_datum_cbor(client, hash) do
    case Req.get(client, url: "scripts/datum/#{hash}/cbor") do
      {:ok, %{status: 200, body: %{"cbor" => cbor}}} -> {hash, cbor}
      _ -> nil
    end
  end

  defp fetch_tx_cbor(client, hash) do
    case Req.get(client, url: "txs/#{hash}/cbor") do
      {:ok, %{status: 200, body: %{"cbor" => cbor}}} -> {hash, cbor}
      _ -> nil
    end
  end

  # Helper parsers

  defp fetch_tx_utxos(client, tx_id, indices) do
    Req.get!(client, url: "txs/#{tx_id}/utxos").body["outputs"]
    |> Enum.filter(fn %{"output_index" => index} -> index in indices end)
    |> Enum.map(fn out -> parse_utxo(Map.put(out, "tx_hash", tx_id)) end)
  end

  defp parse_utxo(data) do
    datum =
      cond do
        data["inline_datum"] -> %Datum{kind: :inline_datum, value: data["inline_datum"]}
        data["data_hash"] -> %Datum{kind: :datum_hash, value: data["data_hash"]}
        true -> %Datum{kind: :no_datum}
      end

    %Input{
      output_reference: %OutputReference{
        transaction_id: data["tx_hash"],
        output_index: data["output_index"]
      },
      output: %Output{
        address: Address.from_bech32(data["address"]),
        datum: datum,
        value: parse_amount(data["amount"]),
        reference_script: data["reference_script_hash"]
      }
    }
  end

  defp parse_amount(amounts) do
    Enum.reduce(amounts, Asset.zero(), fn %{"unit" => unit, "quantity" => q}, acc ->
      quantity = String.to_integer(q)

      case unit do
        "lovelace" ->
          Asset.add(acc, "lovelace", quantity)

        <<policy::binary-size(56), asset_name::binary>> ->
          Asset.add(acc, policy, asset_name, quantity)

        _ ->
          acc
      end
    end)
  end

  defp parse_protocol_params(data) do
    %ProtocolParams{
      min_fee_A: data["min_fee_a"],
      min_fee_B: data["min_fee_b"],
      max_transaction_size: data["max_tx_size"],
      max_body_block_size: data["max_block_size"],
      max_block_header_size: data["max_block_header_size"],
      key_deposit: String.to_integer(data["key_deposit"]),
      pool_deposit: String.to_integer(data["pool_deposit"]),
      maximum_epoch: data["max_epoch"],
      desired_number_of_stake_pool: data["n_opt"],
      pool_pledge_influence: data["a0"] |> Float.ratio(),
      expansion_rate: data["rho"] |> Float.ratio(),
      treasury_growth_rate: data["tau"] |> Float.ratio(),
      min_pool_cost: String.to_integer(data["min_pool_cost"]),
      ada_per_utxo_byte: String.to_integer(data["coins_per_utxo_size"]),
      cost_models: %CostModels{
        plutus_v1: data["cost_models_raw"]["PlutusV1"],
        plutus_v2: data["cost_models_raw"]["PlutusV2"],
        plutus_v3: data["cost_models_raw"]["PlutusV3"]
      },
      execution_costs: %ExecutionUnitPrice{
        mem_price: data["price_mem"] |> Float.ratio(),
        step_price: data["price_step"] |> Float.ratio()
      },
      max_tx_ex_units: %ExecutionUnits{
        mem: data["max_tx_ex_mem"] |> String.to_integer(),
        step: data["max_tx_ex_steps"] |> String.to_integer()
      },
      max_block_ex_units: %ExecutionUnits{
        mem: data["max_block_ex_mem"] |> String.to_integer(),
        step: data["max_block_ex_steps"] |> String.to_integer()
      },
      max_value_size: data["max_val_size"] |> String.to_integer(),
      collateral_percentage: data["collateral_percent"],
      max_collateral_inputs: data["max_collateral_inputs"],
      min_fee_ref_script_cost_per_byte: data["min_fee_ref_script_cost_per_byte"]
    }
  end
end
