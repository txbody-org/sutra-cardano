defmodule Sutra.Provider.YaciProvider do
  @moduledoc """
    Yaci Devkit Provider
  """
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.ProtocolParams
  alias Sutra.SlotConfig
  alias Sutra.Utils

  @default_yaci_general_api_url "http://localhost:8080"
  @default_yaci_admin_api_url "http://localhost:10000"

  @behaviour Sutra.Provider

  defp fetch_endpoint(endpoint_type) when endpoint_type in [:general, :admin] do
    yaci_cfg = Application.get_env(:sutra, :yaci) || []

    case endpoint_type do
      :general ->
        Keyword.get(yaci_cfg, :general_api, @default_yaci_general_api_url) <> "/api/v1"

      :admin ->
        Keyword.get(yaci_cfg, :admin_api, @default_yaci_admin_api_url) <> "/local-cluster/api"
    end
  end

  @impl true
  def protocol_params do
    case fetch_protocol_params(3) do
      {:error, reason} -> raise reason
      protocol_params -> protocol_params
    end
  end

  def fetch_protocol_params(retry \\ 0) do
    url = "#{fetch_endpoint(:general)}/epochs/latest/parameters"

    case Req.get(url, max_retries: retry, retry_log_level: false) do
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
            plutus_v1: resp["cost_models"]["PlutusV1"] |> Map.values(),
            plutus_v2: resp["cost_models"]["PlutusV2"] |> Map.values(),
            plutus_v3: resp["cost_models"]["PlutusV3"] |> Map.values()
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

  @impl true
  def utxos_at(addresses) when is_list(addresses) do
    addresses
    |> Enum.map(fn addr ->
      Task.async(fn ->
        do_fetch_utxo_at_address(addr)
      end)
    end)
    |> Task.await_many()
    |> Utils.merge_list()
    |> Enum.map(&parse_utxo/1)
  end

  defp do_fetch_utxo_at_address(%Address{} = addr),
    do: Address.to_bech32(addr) |> do_fetch_utxo_at_address()

  defp do_fetch_utxo_at_address(address) when is_binary(address) do
    url =
      "#{fetch_endpoint(:admin)}/addresses/#{address}/utxos?page=1"

    Req.get!(url).body
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp parse_utxo(resp) do
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
          {Datum.inline(inline_datum), inline_datum}

        %{"data_hash" => datum_hash} when is_binary(datum_hash) ->
          {Datum.datum_hash(datum_hash), Map.get(datum_of(datum_hash), datum_hash)}

        _ ->
          {Datum.no_datum(), nil}
      end

    %Input{
      output_reference: %OutputReference{
        transaction_id: resp["tx_hash"],
        output_index: resp["output_index"]
      },
      output: %Output{
        address: Address.from_bech32(resp["address"]),
        reference_script: ref_script,
        datum: datum,
        value: parse_asset(resp["amount"]),
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

  @impl true
  def utxos_at_refs(refs) do
    Enum.map(refs, &do_fetch_utxo_at_address/1)
  end

  def do_fetch_utxo_at_ref(<<t_id::binary-size(64), _::binary-size(1), indx::binary>>) do
    do_fetch_utxo_at_ref(%OutputReference{transaction_id: t_id, output_index: indx})
  end

  def do_fetch_utxo_at_ref(%OutputReference{} = ref) do
    url = "#{fetch_endpoint(:general)}/utxos/#{ref.transaction_id}/#{ref.output_index}"

    Req.get!(url).body
    |> parse_utxo()
  end

  @impl true
  def network, do: :testnet

  @impl true
  def submit_tx(tx_cbor) when is_binary(tx_cbor) do
    url = "#{fetch_endpoint(:admin)}/tx/submit"

    Req.post!(url,
      body: tx_cbor,
      headers: %{
        "Content-Type" => "application/cbor"
      }
    ).body
  end

  def submit_tx(%Transaction{} = tx) do
    Transaction.to_cbor(tx)
    |> CBOR.encode()
    |> submit_tx()
  end

  @impl true
  def datum_of(datum_hashes) when is_list(datum_hashes) do
    Enum.reduce(datum_hashes, %{}, fn hash, acc ->
      if is_binary(hash), do: Map.merge(acc, datum_of(hash)), else: acc
    end)
  end

  def datum_of(datum_hash) when is_binary(datum_hash) do
    url = "#{fetch_endpoint(:general)}/scripts/datum/#{datum_hash}/cbor"

    case Req.get!(url).body do
      %{"cbor" => raw_cbor} -> %{datum_hash => raw_cbor}
      _ -> %{}
    end
  end

  @impl true
  def slot_config do
    yaci_cfg = Application.get_env(:sutra, :yaci) || []

    case yaci_cfg[:slot_config] do
      %SlotConfig{} = slot_cfg ->
        slot_cfg

      _ ->
        get_slot_config()
    end
  end

  def get_slot_config do
    url = "#{fetch_endpoint(:admin)}/admin/devnet/genesis/shelley"

    resp =
      Req.get!(url).body

    {:ok, zero_time, _} =
      DateTime.from_iso8601(resp["systemStart"])

    %Sutra.SlotConfig{
      zero_time: DateTime.to_unix(zero_time, :millisecond),
      slot_length: resp["slotLength"] * 1000,
      zero_slot: 0
    }
  end

  def topup(address, qty) when is_integer(qty) and is_binary(address) do
    url = "#{fetch_endpoint(:admin)}/addresses/topup"

    Req.post!(url, json: %{"address" => address, "adaAmount" => qty}).body
  end

  def topup(%Address{} = addr, qty), do: Address.to_bech32(addr) |> topup(qty)

  def running? do
    case fetch_protocol_params(0) do
      %ProtocolParams{} -> true
      _ -> false
    end
  end

  def balance_of(address) when is_binary(address) do
    url = "#{fetch_endpoint(:general)}/addresses/#{address}/balance"

    case Req.get!(url) do
      %Req.Response{status: 200, body: %{"amounts" => amounts}} -> parse_asset(amounts)
      _ -> Asset.zero()
    end
  end

  def balance_of(%Address{} = addr), do: Address.to_bech32(addr) |> balance_of()

  def get_tx_info(tx_id) when is_binary(tx_id) do
    url = "#{fetch_endpoint(:general)}/txs/#{tx_id}"

    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: resp}} -> resp
      _ -> nil
    end
  end
end
