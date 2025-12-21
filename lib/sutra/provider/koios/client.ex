defmodule Sutra.Provider.Koios.Client do
  @moduledoc """
    Client for Koios API using Req.
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Transaction.{Datum, Input, Output, OutputReference}
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.ProtocolParams

  def new(opts \\ []) do
    network = opts[:network] || :mainnet
    api_key = opts[:api_key]

    network_prefix = network |> Atom.to_string() |> String.downcase()
    base_url = "https://#{network_prefix}.koios.rest/api/v1/"

    headers = [
      {"accept", "application/json"},
      {"content-type", "application/json"}
    ]

    headers =
      if api_key do
        headers ++ [{"authorization", "Bearer #{api_key}"}]
      else
        headers
      end

    Req.new(base_url: base_url, headers: headers)
  end

  def utxos_at_addresses(client, addresses) do
    normalized_addrs =
      Enum.map(addresses, fn addr ->
        if is_binary(addr), do: addr, else: Address.to_bech32(addr)
      end)

    resp =
      Req.post!(client,
        url: "address_utxos",
        json: %{
          "_addresses" => normalized_addrs,
          "_extended" => true
        }
      ).body

    Enum.map(resp, &parse_utxo/1)
  end

  def utxos_at_tx_refs(client, refs) do
    normalized_refs =
      Enum.map(refs, fn
        %OutputReference{transaction_id: tx_id, output_index: index} -> "#{tx_id}##{index}"
        ref when is_binary(ref) -> ref
      end)

    resp =
      Req.post!(client,
        url: "utxo_info",
        json: %{"_utxo_refs" => normalized_refs, "_extended" => true}
      ).body

    Enum.map(resp, &parse_utxo/1)
  end

  def datum_of(client, datum_hashes) do
    resp =
      Req.post!(client,
        url: "datum_info",
        json: %{"_datum_hashes" => datum_hashes}
      ).body

    for %{"datum_hash" => hash, "bytes" => raw_datum} <- resp, into: %{} do
      {hash, raw_datum}
    end
  end

  def protocol_params(client) do
    curr_epoch_no = Req.get!(client, url: "tip").body |> hd() |> Map.get("epoch_no")

    Req.get!(client, url: "epoch_params", params: %{"_epoch_no" => curr_epoch_no})
    |> Map.get(:body)
    |> hd()
    |> parse_protocol_params()
  end

  def submit_tx(client, cbor) when is_binary(cbor) do
    Req.post!(client,
      url: "submittx",
      body: cbor,
      headers: %{"content-type" => "application/cbor"}
    ).body
  end

  def tx_cbor(client, tx_hashes) do
    resp =
      Req.post!(client,
        url: "tx_cbor",
        json: %{"_tx_hashes" => tx_hashes}
      ).body

    Enum.into(resp, %{}, &{&1["tx_hash"], &1["cbor"]})
  end

  # Helper parsers (copied from original KoiosProvider)

  defp parse_protocol_params(protocol_params_map) do
    %ProtocolParams{
      min_fee_A: protocol_params_map["min_fee_a"],
      min_fee_B: protocol_params_map["min_fee_b"],
      max_body_block_size: protocol_params_map["max_block_size"],
      max_transaction_size: protocol_params_map["max_tx_size"],
      max_block_header_size: protocol_params_map["max_bh_size"],
      key_deposit: protocol_params_map["key_deposit"] |> String.to_integer(),
      pool_deposit: protocol_params_map["pool_deposit"] |> String.to_integer(),
      maximum_epoch: protocol_params_map["max_epoch"],
      desired_number_of_stake_pool: protocol_params_map["optimal_pool_count"],
      pool_pledge_influence: protocol_params_map["influence"] |> Float.ratio(),
      expansion_rate: protocol_params_map["monetary_expand_rate"] |> Float.ratio(),
      treasury_growth_rate: protocol_params_map["treasury_growth_rate"] |> Float.ratio(),
      min_pool_cost: protocol_params_map["min_pool_cost"] |> String.to_integer(),
      ada_per_utxo_byte: protocol_params_map["coins_per_utxo_size"] |> String.to_integer(),
      cost_models: %CostModels{
        plutus_v1: protocol_params_map["cost_models"]["PlutusV1"],
        plutus_v2: protocol_params_map["cost_models"]["PlutusV2"],
        plutus_v3: protocol_params_map["cost_models"]["PlutusV3"]
      },
      execution_costs: %ExecutionUnitPrice{
        mem_price: protocol_params_map["price_mem"] |> Float.ratio(),
        step_price: protocol_params_map["price_step"] |> Float.ratio()
      },
      max_tx_ex_units: %ExecutionUnits{
        mem: protocol_params_map["max_tx_ex_mem"],
        step: protocol_params_map["max_tx_ex_steps"]
      },
      max_block_ex_units: %ExecutionUnits{
        mem: protocol_params_map["max_block_ex_mem"],
        step: protocol_params_map["max_block_ex_step"]
      },
      max_value_size: protocol_params_map["max_val_size"],
      collateral_percentage: protocol_params_map["collateral_percent"],
      max_collateral_inputs: protocol_params_map["max_collateral_inputs"],
      min_fee_ref_script_cost_per_byte: protocol_params_map["min_fee_ref_script_cost_per_byte"]
    }
  end

  def parse_utxo(result) do
    datum = extract_datum(result)

    datum_raw =
      if datum.kind == :inline_datum, do: datum.value, else: nil

    %Input{
      output_reference: %OutputReference{
        transaction_id: result["tx_hash"],
        output_index: result["tx_index"]
      },
      output: %Output{
        address: Address.from_bech32(result["address"]),
        datum: datum,
        reference_script: result["reference_script"],
        datum_raw: datum_raw,
        value: parse_asset_list(result["value"], result["asset_list"])
      }
    }
  end

  defp extract_datum(%{"inline_datum" => %{"bytes" => datum_val}}) when is_binary(datum_val),
    do: %Datum{kind: :inline_datum, value: datum_val}

  defp extract_datum(%{"datum_hash" => datum_hash}) when is_binary(datum_hash),
    do: %Datum{kind: :datum_hash, value: datum_hash}

  defp extract_datum(_), do: %Datum{kind: :no_datum}

  defp parse_asset_list(lovelace, assets) do
    assets = if is_nil(assets), do: [], else: assets

    Enum.reduce(assets, %{"lovelace" => String.to_integer(lovelace)}, fn asset, acc ->
      prev_asset_policy = Map.get(acc, asset["policy_id"], %{})

      Map.put(
        acc,
        asset["policy_id"],
        Map.put(prev_asset_policy, asset["asset_name"], asset["quantity"] |> String.to_integer())
      )
    end)
  end
end
