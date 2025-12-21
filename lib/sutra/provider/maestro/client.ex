defmodule Sutra.Provider.Maestro.Client do
  @moduledoc """
    Client for Maestro API using Req.
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Transaction.{Datum, Input, Output, OutputReference}
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.ProtocolParams

  def new(opts \\ []) do
    api_key = opts[:api_key]
    network = opts[:network] || :mainnet

    base_url =
      opts[:base_url] ||
        case network do
          :mainnet -> "https://mainnet.gomaestro-api.org/v1"
          :preprod -> "https://preprod.gomaestro-api.org/v1"
          :preview -> "https://preview.gomaestro-api.org/v1"
          _ -> raise "Unsupported Maestro network: #{network}"
        end

    Req.new(
      base_url: base_url,
      headers: [
        {"api-key", api_key},
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
        Req.get!(client, url: "addresses/#{addr_str}/utxos", params: [resolve_datums: true]).body[
          "data"
        ]
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
    |> Enum.map(fn {tx_id, index} ->
      Task.async(fn ->
        Req.get!(client,
          url: "transactions/#{tx_id}/outputs/#{index}/txo",
          params: [resolve_datums: true]
        ).body["data"]
        |> parse_utxo()
        |> Map.put(:output_reference, %OutputReference{transaction_id: tx_id, output_index: index})
      end)
    end)
    |> Task.await_many(30_000)
  end

  def protocol_params(client) do
    Req.get!(client, url: "protocol-parameters").body["data"]
    |> parse_protocol_params()
  end

  def submit_tx(client, cbor) do
    resp =
      Req.post!(client,
        url: "txmanager",
        body: cbor,
        headers: %{"content-type" => "application/cbor"}
      )

    resp.body
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

  defp fetch_tx_cbor(client, hash) do
    case Req.get(client, url: "transactions/#{hash}/cbor") do
      {:ok, %{status: 200, body: %{"cbor" => cbor}}} -> {hash, cbor}
      _ -> nil
    end
  end

  # Helper parsers

  defp parse_utxo(data) do
    datum =
      case data["datum"] do
        %{"type" => "inline", "bytes" => bytes} -> %Datum{kind: :inline_datum, value: bytes}
        %{"type" => "hash", "hash" => hash} -> %Datum{kind: :datum_hash, value: hash}
        _ -> %Datum{kind: :no_datum}
      end

    # Note: Maestro might provide the datum bytes separately if resolve_datums=true
    # The structure might be slightly different depending on version.

    %Input{
      output_reference: %OutputReference{
        transaction_id: data["tx_hash"],
        output_index: data["index"]
      },
      output: %Output{
        address: Address.from_bech32(data["address"]),
        datum: datum,
        value: parse_assets(data["assets"]),
        reference_script: data["reference_script"] && data["reference_script"]["hash"],
        datum_raw: data["datum"] && data["datum"]["bytes"]
      }
    }
  end

  defp parse_assets(assets) do
    Enum.reduce(assets, Asset.zero(), fn %{"unit" => unit, "amount" => q}, acc ->
      quantity = q

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
      min_fee_A: data["min_fee_coefficient"],
      min_fee_B: data["min_fee_constant"] |> parse_coin(),
      max_transaction_size: data["max_tx_size"],
      max_body_block_size: data["max_block_body_size"],
      max_block_header_size: data["max_block_header_size"],
      key_deposit: data["stake_credential_deposit"] |> parse_coin(),
      pool_deposit: data["stake_pool_deposit"] |> parse_coin(),
      maximum_epoch: data["max_epoch"],
      desired_number_of_stake_pool: data["desired_number_of_stake_pools"],
      pool_pledge_influence: data["stake_pool_pledge_influence"] |> parse_ratio(),
      expansion_rate: data["monetary_expansion"] |> parse_ratio(),
      treasury_growth_rate: data["treasury_expansion"] |> parse_ratio(),
      min_pool_cost: data["min_stake_pool_cost"] |> parse_coin(),
      ada_per_utxo_byte: data["min_utxo_deposit_coefficient"] |> parse_coin(),
      cost_models: %CostModels{
        plutus_v1: data["plutus_cost_models"]["plutus_v1"] |> convert_cost_model(),
        plutus_v2: data["plutus_cost_models"]["plutus_v2"] |> convert_cost_model(),
        plutus_v3: data["plutus_cost_models"]["plutus_v3"] |> convert_cost_model()
      },
      execution_costs: %ExecutionUnitPrice{
        mem_price: data["script_execution_prices"]["memory"] |> parse_ratio(),
        step_price: data["script_execution_prices"]["cpu"] |> parse_ratio()
      },
      max_tx_ex_units: %ExecutionUnits{
        mem: data["max_execution_units_per_transaction"]["memory"],
        step: data["max_execution_units_per_transaction"]["cpu"]
      },
      max_block_ex_units: %ExecutionUnits{
        mem: data["max_execution_units_per_block"]["memory"],
        step: data["max_execution_units_per_block"]["cpu"]
      },
      max_value_size: data["max_value_size"],
      collateral_percentage: data["collateral_percentage"],
      max_collateral_inputs: data["max_collateral_inputs"],
      min_fee_ref_script_cost_per_byte: data["min_fee_reference_scripts"]["base"]
    }
  end

  def evaluate_tx(client, cbor) do
    # Maestro expects JSON with cbor field
    resp =
      Req.post!(client,
        url: "tx/evaluate",
        json: %{"cbor" => Base.encode16(cbor), "additional_utxos" => []}
      ).body

    # Maestro response format:
    # [
    #   {
    #     "redeemer_tag": "Spend",
    #     "redeemer_index": 0,
    #     "ex_units": { "mem": 123, "steps": 456 }
    #   }
    # ]
    # Or error.

    case resp do
      list when is_list(list) ->
        files =
          Enum.map(list, fn item ->
            # "Spend" -> "spend"
            tag = String.downcase(item["redeemer_tag"])
            index = item["redeemer_index"]
            mem = item["ex_units"]["mem"]
            steps = item["ex_units"]["steps"]

            {"#{tag}:#{index}", %ExecutionUnits{mem: mem, step: steps}}
          end)
          |> Map.new()

        {:ok, files}

      %{"message" => msg} ->
        {:error, msg}

      _ ->
        {:error, inspect(resp)}
    end
  end

  defp parse_coin(%{"ada" => %{"lovelace" => amount}}), do: amount
  defp parse_coin(%{"lovelace" => amount}), do: amount
  defp parse_coin(amount) when is_integer(amount), do: amount
  defp parse_coin(_), do: 0

  defp parse_ratio(val) when is_float(val), do: Float.ratio(val)

  defp parse_ratio(val) when is_binary(val) do
    case String.split(val, "/") do
      [n, d] -> {String.to_integer(n), String.to_integer(d)}
      [n] -> {String.to_integer(n), 1}
    end
  end

  defp parse_ratio(_), do: {0, 1}

  defp convert_cost_model(nil), do: []

  defp convert_cost_model(model) when is_map(model) do
    Map.keys(model)
    |> Enum.sort()
    |> Enum.map(&Map.get(model, &1))
  end

  defp convert_cost_model(model) when is_list(model), do: model
  defp convert_cost_model(_), do: []
end
