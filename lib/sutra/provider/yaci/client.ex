defmodule Sutra.Provider.Yaci.Client do
  @moduledoc """
    Client for Yaci Devkit API using Req.
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.Data
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig
  alias Sutra.Utils

  def new(opts \\ []) do
    general_api_url = opts[:general_api_url]
    admin_api_url = opts[:admin_api_url]

    %{
      general: Req.new(base_url: "#{general_api_url}/api/v1"),
      admin: Req.new(base_url: "#{admin_api_url}/local-cluster/api")
    }
  end

  def protocol_params(clients, retry \\ 0) do
    # Map with size greater than 32, keys are not sorted by default
    sorted_map_list = fn map ->
      Map.keys(map)
      |> Enum.sort()
      |> Enum.map(&Map.get(map, &1))
    end

    case Req.get(clients.admin,
           url: "epochs/parameters",
           max_retries: retry,
           retry_log_level: false
         ) do
      {:ok, %Req.Response{status: 200, body: resp}} ->
        %ProtocolParams{
          min_fee_A: resp["min_fee_a"],
          min_fee_B: resp["min_fee_b"],
          max_transaction_size: resp["max_tx_size"],
          max_body_block_size: resp["max_block_size"],
          max_block_header_size: resp["max_block_header_size"],
          key_deposit: resp["key_deposit"] |> String.to_integer(),
          pool_deposit: resp["pool_deposit"] |> String.to_integer(),
          maximum_epoch: resp["max_epoch"],
          ada_per_utxo_byte: String.to_integer(resp["coins_per_utxo_size"]),
          min_pool_cost: String.to_integer(resp["min_pool_cost"]),
          cost_models: %CostModels{
            plutus_v1: resp["cost_models"]["PlutusV1"] |> sorted_map_list.(),
            plutus_v2: resp["cost_models"]["PlutusV2"] |> sorted_map_list.(),
            plutus_v3: resp["cost_models"]["PlutusV3"] |> sorted_map_list.()
          },
          execution_costs: %ExecutionUnitPrice{
            mem_price: Float.ratio(resp["price_mem"]),
            step_price: Float.ratio(resp["price_step"])
          },
          max_tx_ex_units: %ExecutionUnits{
            mem: String.to_integer(resp["max_tx_ex_mem"]),
            step: String.to_integer(resp["max_tx_ex_steps"])
          },
          max_block_ex_units: %ExecutionUnits{
            mem: String.to_integer(resp["max_block_ex_mem"]),
            step: String.to_integer(resp["max_block_ex_steps"])
          },
          max_value_size: String.to_integer(resp["max_val_size"]),
          collateral_percentage: resp["collateral_percent"],
          max_collateral_inputs: resp["max_collateral_inputs"],
          min_fee_ref_script_cost_per_byte: resp["min_fee_ref_script_cost_per_byte"]
        }

      _ ->
        {:error, "Cannot fetch protocol params"}
    end
  end

  def utxos_at_addresses(clients, addresses) do
    addresses
    |> Enum.map(fn addr ->
      Task.async(fn ->
        do_fetch_utxo_at_address(clients, addr)
      end)
    end)
    |> Task.await_many()
    |> Utils.merge_list()
    |> Enum.map(&parse_utxo(&1, clients))
  end

  defp do_fetch_utxo_at_address(clients, %Address{} = addr),
    do: do_fetch_utxo_at_address(clients, Address.to_bech32(addr))

  defp do_fetch_utxo_at_address(clients, address) when is_binary(address) do
    Req.get!(clients.admin, url: "addresses/#{address}/utxos?page=1").body
  end

  def utxos_at_tx_refs(clients, refs) do
    Enum.map(refs, &do_fetch_utxo_at_ref(clients, &1))
  end

  defp do_fetch_utxo_at_ref(clients, <<t_id::binary-size(64), _::binary-size(1), indx::binary>>) do
    do_fetch_utxo_at_ref(clients, %OutputReference{transaction_id: t_id, output_index: indx})
  end

  defp do_fetch_utxo_at_ref(clients, %OutputReference{} = ref) do
    Req.get!(clients.general, url: "utxos/#{ref.transaction_id}/#{ref.output_index}").body
    |> parse_utxo(clients)
  end

  def datum_of(clients, datum_hashes) when is_list(datum_hashes) do
    Enum.reduce(datum_hashes, %{}, fn hash, acc ->
      if is_binary(hash), do: Map.merge(acc, datum_of(clients, hash)), else: acc
    end)
  end

  def datum_of(clients, datum_hash) when is_binary(datum_hash) do
    case Req.get!(clients.general, url: "scripts/datum/#{datum_hash}/cbor").body do
      %{"cbor" => raw_cbor} -> %{datum_hash => raw_cbor}
      _ -> %{}
    end
  end

  def submit_tx(clients, tx_cbor) do
    Req.post!(clients.admin,
      url: "tx/submit",
      body: tx_cbor,
      headers: %{"Content-Type" => "application/cbor"}
    ).body
  end

  def slot_config(clients) do
    resp = Req.get!(clients.admin, url: "admin/devnet/genesis/shelley").body

    {:ok, zero_time, _} =
      DateTime.from_iso8601(resp["systemStart"])

    %SlotConfig{
      zero_time: DateTime.to_unix(zero_time, :millisecond),
      slot_length: resp["slotLength"] * 1000,
      zero_slot: 0
    }
  end

  # Helper parsers

  defp parse_utxo(resp, clients) do
    ref_script =
      case resp do
        %{"script_ref" => ref} when is_binary(ref) ->
          Script.from_script_ref(ref)

        %{"reference_script_hash" => ref} when is_binary(ref) ->
          Script.from_script_ref(ref)

        _ ->
          nil
      end

    {datum, raw} =
      case resp do
        %{"inline_datum" => inline_datum} when is_binary(inline_datum) ->
          {Datum.inline(inline_datum), Data.decode!(inline_datum)}

        %{"data_hash" => datum_hash} when is_binary(datum_hash) ->
          raw_datum =
            Map.get(datum_of(clients, datum_hash), datum_hash)
            |> Utils.maybe(nil, &Data.decode!/1)

          {Datum.datum_hash(datum_hash), raw_datum}

        _ ->
          {Datum.no_datum(), nil}
      end

    address = Utils.maybe(resp["address"], resp["owner_addr"]) |> Address.from_bech32()

    assets = Utils.maybe(resp["amount"], resp["amounts"]) |> parse_asset()

    %Input{
      output_reference: %OutputReference{
        transaction_id: resp["tx_hash"],
        output_index: resp["output_index"]
      },
      output: %Output{
        address: address,
        reference_script: ref_script,
        datum: datum,
        value: assets,
        datum_raw: raw
      }
    }
  end

  defp parse_asset(amounts) do
    Enum.reduce(amounts, Asset.zero(), fn value, acc ->
      case value do
        %{"unit" => "lovelace"} ->
          Asset.add(acc, "lovelace", value["quantity"])

        %{"unit" => <<policy_id::binary-size(56), asset_name::binary>>} ->
          Asset.add(acc, policy_id, asset_name, value["quantity"])

        _ ->
          acc
      end
    end)
  end

  # Extra functions from original provider (topup, balance_of, etc.)

  def topup(clients, address, qty) do
    Req.post!(clients.admin,
      url: "addresses/topup",
      json: %{"address" => address, "adaAmount" => qty}
    ).body
  end

  def balance_of(clients, address) do
    case Req.get!(clients.general, url: "addresses/#{address}/balance") do
      %Req.Response{status: 200, body: %{"amounts" => amounts}} -> parse_asset(amounts)
      _ -> Asset.zero()
    end
  end

  def get_tx_info(clients, tx_id) do
    case Req.get(clients.general, url: "txs/#{tx_id}") do
      {:ok, %Req.Response{status: 200, body: resp}} -> resp
      _ -> nil
    end
  end
end
