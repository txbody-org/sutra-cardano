defmodule Sutra.Cardano.Transaction.TxBody do
  @moduledoc """
    Cardano Transaction Body
  """
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Certificate
  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.Output.OutputReference
  alias Sutra.Utils

  import Sutra.Data.Cbor, only: [extract_value!: 1]
  import Utils, only: [maybe: 3]
  use TypedStruct

  typedstruct do
    # --- 0
    field(:inputs, [OutputReference.t()])
    # --- 1
    field(:outputs, [Output.t()])
    # --- 2
    field(:fee, :integer)
    # --- (3) Slot Number
    field(:ttl, :integer)
    # --- (4) Certificates -- TODO create Type
    field(:certificates, [])
    # --- (5) Withdrawals
    field(:withdrawals, [])
    # --- (6) Update
    field(:update, nil)
    # --- (7) Auxiliary Data Hash
    field(:auxiliary_data_hash, nil)
    # --- (8)
    field(:validaty_interval_start, :integer)
    # --- (9)
    field(:mint, :map)
    # --- (11)
    field(:script_data_hash, :string)
    # -- (13)
    field(:collateral, [OutputReference.t()])
    # -- (14)
    field(:required_signers, [String.t()])
    # -- (15)
    field(:network_id, :string)
    # -- (16)
    field(:collateral_return, :integer)
    # -- (17)
    field(:total_collateral, :integer)
    # -- (18)
    field(:reference_inputs, [OutputReference.t()])

    # --- New Fields in Conway Era
    # -- (19)
    field(:voting_procedures, any())
    # -- (20)
    field(:proposal_procedures, any())
    # -- (21)
    field(:current_treasury_value, :integer)
    # -- (22)
    field(:treasury_donation, :integer)
  end

  def decode(tx_body) when is_map(tx_body) do
    network_id = if tx_body[15] == 1, do: "mainnet", else: "testnet"

    certificates =
      tx_body[4]
      |> maybe([], &extract_value!/1)
      |> Enum.map(&Certificate.decode/1)

    %__MODULE__{
      inputs: parse_inputs(tx_body[0]),
      outputs: Enum.map(tx_body[1], &parse_tx_outputs/1),
      fee: Asset.lovelace_of(tx_body[2]),
      ttl: tx_body[3],
      certificates: certificates,
      auxiliary_data_hash: extract_value!(tx_body[7]),
      validaty_interval_start: tx_body[8],
      mint: maybe(tx_body[9], nil, &Asset.from_plutus/1) |> Utils.ok_or(nil),
      script_data_hash: extract_value!(tx_body[11]),
      collateral: parse_inputs(extract_value!(tx_body[13]) || []),
      network_id: network_id,
      collateral_return: maybe(tx_body[16], nil, &parse_tx_outputs/1),
      total_collateral: maybe(tx_body[17], nil, &parse_value/1),
      reference_inputs: parse_inputs(extract_value!(tx_body[18]) || [])
    }
  end

  defp parse_inputs(%CBOR.Tag{tag: 258, value: inputs}), do: parse_inputs(inputs)

  defp parse_inputs(inputs) when is_list(inputs) do
    Enum.map(inputs, fn [tx_id, index] ->
      %OutputReference{
        transaction_id: extract_value!(tx_id),
        output_index: index
      }
    end)
  end

  # pre babbage Transaction output
  defp parse_tx_outputs([%CBOR.Tag{value: raw_addr} | [amt | dtm_hash]])
       when is_binary(raw_addr) do
    %Output{
      address: Address.Parser.decode(raw_addr),
      value: parse_value(amt),
      datum: dtm_hash |> Utils.safe_head() |> parse_datum()
    }
  end

  defp parse_tx_outputs(%{0 => %CBOR.Tag{tag: :bytes, value: addr_value}} = ops) do
    %Output{
      address: Address.Parser.decode(addr_value),
      value: parse_value(ops[1]),
      datum: parse_datum(ops[2]),
      reference_script: ops[3]
    }
  end

  # datum_hash = $hash32
  defp parse_datum(datum_hash) when is_binary(datum_hash),
    do: %Datum{kind: :datum_hash, value: datum_hash}

  # datum_option = [0, $hash32 // 1, data]
  defp parse_datum([0, datum_hash]), do: %Datum{kind: :datum_hash, value: datum_hash}

  defp parse_datum([1, %CBOR.Tag{tag: 24, value: %CBOR.Tag{tag: :bytes, value: data}}]),
    do: %Datum{kind: :inline_datum, value: data}

  defp parse_datum(_), do: %Datum{kind: :no_datum}

  defp parse_value(lovelace) when is_integer(lovelace), do: Asset.lovelace_of(lovelace)

  defp parse_value([lovelace, other_assets]) do
    with {:ok, assets} <- Asset.from_plutus(other_assets) do
      Map.put(assets, "lovelace", lovelace)
    end
  end
end
