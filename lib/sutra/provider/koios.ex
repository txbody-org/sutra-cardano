defmodule Sutra.Provider.KoiosProvider do
  @moduledoc """
    Koios Data provider
  """

  @behaviour Sutra.Provider

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.{Datum, Input, Output, OutputReference}
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.Data
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig
  alias Sutra.Utils

  defp fetch_env(key), do: Application.get_env(:sutra, :koios)[key]

  defp base_url do
    network_prefix = network() |> Atom.to_string() |> String.downcase()
    "https://#{network_prefix}.koios.rest/api/v1/"
  end

  @impl true
  def network, do: fetch_env(:network)

  def api_key do
    fetch_env(:api_key)
  end

  @impl true
  def utxos_at(addrs) when is_list(addrs) do
    normalized_addrs =
      Enum.map(addrs, fn addr ->
        if is_binary(addr), do: addr, else: Address.to_bech32(addr)
      end)

    resp =
      build_request(:post, "address_utxos", %{
        "_addresses" => normalized_addrs,
        "_extended" => true
      })
      |> Map.get(:body)

    Enum.map(resp, &parse_utxo/1)
    |> attach_datum_raw_to_utxos()
  end

  @impl true
  def utxos_at_refs(refs) do
    resp =
      build_request(:post, "utxo_info", %{"_utxo_refs" => refs, "_extended" => true})
      |> Map.get(:body)

    resp
    |> Enum.map(&parse_utxo/1)
    |> attach_datum_raw_to_utxos()
  end

  @impl true
  def tx_cbor(tx_hash) when is_list(tx_hash) do
    resp =
      build_request(:post, "tx_cbor", %{"_tx_hashes" => tx_hash})
      |> Map.get(:body)

    Enum.into(resp, %{}, &{&1["tx_hash"], &1["cbor"]})
  end

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

  @impl true
  def datum_of([]), do: %{}

  def datum_of(datum_hashes) when is_list(datum_hashes) do
    resp =
      build_request(:post, "datum_info", %{"_datum_hashes" => datum_hashes})
      |> Map.get(:body)

    for %{"datum_hash" => hash, "bytes" => raw_datum} <- resp, into: %{} do
      {hash, raw_datum}
    end
  end

  def chain_tip do
    Req.get!(base_url() <> "tip").body
  end

  @impl true
  def protocol_params do
    curr_epoch_no = chain_tip() |> hd() |> Map.get("epoch_no")

    build_request(:get, "epoch_params", %{"_epoch_no" => curr_epoch_no})
    |> Map.get(:body)
    |> hd()
    |> parse_protocol_params()
  end

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

  defp parse_utxo(result) do
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

  @impl true
  def slot_config do
    network()
    |> SlotConfig.fetch_slot_config()
  end

  @impl true
  def submit_tx(cbor) when is_binary(cbor) do
    build_request(:post, "submittx", cbor, headers: %{content_type: "application/cbor"})
    |> Map.get(:body)
  end

  def submit_tx(%Transaction{} = tx) do
    Transaction.to_cbor(tx)
    |> CBOR.encode()
    |> submit_tx()
  end

  defp build_request(method, path, body, opts \\ []) do
    url = base_url() <> path
    headers = build_headers(opts)

    base_req =
      Req.new(
        method: method,
        url: url,
        headers: headers
      )
      |> apply_body(body)

    Req.request!(base_req)
  end

  defp build_headers(opts) do
    header_opts = Keyword.get(opts, :headers, %{})

    base_header = %{
      accept: "application/json",
      content_type: "application/json"
    }

    header = Map.merge(base_header, header_opts)

    case api_key() do
      nil -> header
      key -> Map.put(header, :authorization, "Bearer " <> key)
    end
  end

  defp apply_body(req, body) do
    if body, do: Req.merge(req, json: body), else: req
  end
end
