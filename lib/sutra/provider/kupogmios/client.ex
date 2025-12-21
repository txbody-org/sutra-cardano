defmodule Sutra.Provider.Kupogmios.Client do
  @moduledoc """
    Client for Kupo and Ogmios API using Req.
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Cardano.Transaction.{Datum, Input, Output, OutputReference}
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.Common.ExecutionUnits
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.ProtocolParams
  alias Sutra.Utils
  alias Sutra.Cardano.Asset
  alias Sutra.Data

  import Sutra.Common, only: [rational_from_binary: 1]
  import Sutra.Utils, only: [maybe: 3]

  def new(opts \\ []) do
    kupo_url = opts[:kupo_url]
    ogmios_url = opts[:ogmios_url]

    %{
      kupo: Req.new(base_url: kupo_url),
      ogmios: Req.new(base_url: ogmios_url)
    }
  end

  def protocol_params(clients) do
    params = %{"jsonrpc" => "2.0", "method" => "queryLedgerState/protocolParameters"}

    Req.post!(clients.ogmios, json: params).body
    |> Map.get("result")
    |> parse_protocol_params()
  end

  def utxos_at_addresses(clients, addresses) do
    addresses
    |> Enum.map(fn addr ->
      Task.async(fn ->
        do_fetch_utxos_at_address(clients, addr)
      end)
    end)
    |> Task.await_many()
    |> Utils.merge_list()
  end

  def utxos_at_tx_refs(clients, refs) do
    lookup =
      Enum.reduce(refs, %{}, fn r, acc ->
        case r do
          %OutputReference{transaction_id: t_id, output_index: indx} ->
            Map.put(acc, t_id, [indx | Map.get(acc, t_id, [])])

          <<t_id::binary-size(64), _::binary-size(1), indx::binary>> ->
            Map.put(acc, t_id, [String.to_integer(indx) | Map.get(acc, t_id, [])])

          _ ->
            acc
        end
      end)

    Map.keys(lookup)
    |> Enum.map(&do_fetch_tx_ref(clients, &1, lookup[&1]))
    |> Utils.merge_list()
  end

  def submit_tx(clients, tx_cbor) do
    data = %{
      jsonrpc: "2.0",
      method: "submitTransaction",
      params: %{
        transaction: %{cbor: tx_cbor}
      }
    }

    case Req.post!(clients.ogmios, json: data).body do
      %{"result" => %{"transaction" => tx_resp}} -> tx_resp["id"]
      result -> :elixir_json.encode(result)
    end
  end

  # Helper functions

  defp do_fetch_tx_ref(clients, tx_id, indices) do
    pattern = "*@#{tx_id}?unspent&resolve_hashes"

    Req.get!(clients.kupo, url: "matches/#{pattern}").body
    |> Enum.filter(fn %{"output_index" => indx} ->
      Enum.find(indices, &(&1 == indx)) == indx
    end)
    |> Enum.map(&parse_output/1)
  end

  defp do_fetch_utxos_at_address(clients, address_bech32) when is_binary(address_bech32) do
    Address.from_bech32(address_bech32)
    |> do_fetch_utxos_at_address(clients)
  end

  defp do_fetch_utxos_at_address(
         %Address{
           payment_credential: pay_cred,
           stake_credential: stake_cred
         },
         clients
       ) do
    pay_cred_hash = if pay_cred, do: pay_cred.hash, else: "*"
    stake_cred_hash = if stake_cred, do: stake_cred.hash, else: "*"

    pattern = "#{pay_cred_hash}/#{stake_cred_hash}?unspent&resolve_hashes"

    Req.get!(clients.kupo, url: "matches/#{pattern}").body
    |> Enum.map(&parse_output/1)
  end

  def parse_output(%{"datum" => datum_resp, "script" => script_resp} = result) do
    datum =
      case result["datum_type"] do
        "inline" ->
          %Datum{kind: :inline, value: datum_resp}

        "hash" ->
          %Datum{kind: :datum_hash, value: result["datum_hash"]}

        _ ->
          %Datum{kind: :no_datum, value: nil}
      end

    script =
      case {script_resp["script"], script_resp["language"]} do
        {nil, _} ->
          nil

        {script, "plutus:v1"} ->
          Script.new(script, :plutus_v1)

        {script, "plutus:v2"} ->
          Script.new(script, :plutus_v2)

        {script, "plutus:v3"} ->
          Script.new(script, :plutus_v3)

        {script, "native"} ->
          NativeScript.from_cbor(script)
      end

    %Input{
      output_reference: %OutputReference{
        transaction_id: result["transaction_id"],
        output_index: result["output_index"]
      },
      output: %Output{
        address: Address.from_bech32(result["address"]),
        datum: datum,
        value:
          Asset.from_seperator(result["value"]["assets"])
          |> Asset.add("lovelace", result["value"]["coins"]),
        reference_script: script,
        datum_raw: maybe(datum_resp, nil, &Data.decode!/1)
      }
    }
  end

  defp parse_protocol_params(resp) do
    [mem_price_n, mem_price_d] =
      resp["scriptExecutionPrices"]["memory"]
      |> String.split("/")
      |> Enum.map(&String.to_integer/1)

    [step_price_n, step_price_d] =
      resp["scriptExecutionPrices"]["cpu"]
      |> String.split("/")
      |> Enum.map(&String.to_integer/1)

    %ProtocolParams{
      min_fee_A: resp["minFeeCoefficient"],
      min_fee_B: resp["minFeeConstant"]["ada"]["lovelace"],
      max_transaction_size: resp["maxTransactionSize"]["bytes"],
      max_body_block_size: resp["maxBlockBodySize"]["bytes"],
      max_block_header_size: resp["maxBlockHeaderSize"]["bytes"],
      key_deposit: resp["stakeCredentialDeposit"]["ada"]["lovelace"],
      pool_deposit: resp["stakePoolDeposit"]["ada"]["lovelace"],
      maximum_epoch: nil,
      desired_number_of_stake_pool: resp["desiredNumberOfStakePools"],
      pool_pledge_influence: resp["stakePoolPledgeInfluence"] |> rational_from_binary(),
      expansion_rate: resp["monetaryExpansion"] |> rational_from_binary(),
      treasury_growth_rate: resp["treasuryExpansion"] |> rational_from_binary(),
      min_pool_cost: resp["minStakePoolCost"]["ada"]["lovelace"],
      ada_per_utxo_byte: resp["minUtxoDepositCoefficient"],
      cost_models: %CostModels{
        plutus_v1: resp["plutusCostModels"]["plutus:v1"],
        plutus_v2: resp["plutusCostModels"]["plutus:v2"],
        plutus_v3: resp["plutusCostModels"]["plutus:v3"]
      },
      execution_costs: %ExecutionUnitPrice{
        mem_price: {mem_price_n, mem_price_d},
        step_price: {step_price_n, step_price_d}
      },
      max_tx_ex_units: %ExecutionUnits{
        mem: resp["maxExecutionUnitsPerTransaction"]["memory"],
        step: resp["maxExecutionUnitsPerTransaction"]["cpu"]
      },
      max_block_ex_units: %ExecutionUnits{
        mem: resp["maxExecutionUnitsPerBlock"]["memory"],
        step: resp["maxExecutionUnitsPerBlock"]["cpu"]
      },
      max_value_size: resp["maxValueSize"]["bytes"],
      max_collateral_inputs: resp["maxCollateralInputs"],
      min_fee_ref_script_cost_per_byte: resp["minFeeReferenceScripts"]["base"],
      collateral_percentage: resp["collateralPercentage"]
    }
  end
end
