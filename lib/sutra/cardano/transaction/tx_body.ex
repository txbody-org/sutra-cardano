defmodule Sutra.Cardano.Transaction.TxBody do
  @moduledoc """
    Cardano Transaction Body
  """
  alias CBOR.Utils
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Certificate
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Data.Cbor
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
    # --- (4) Certificates
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
    field(:collateral_return, Output.t())
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

  defp decode_netword_id(0), do: :testnet
  defp decode_netword_id(1), do: :mainnet
  defp decode_netword_id(_), do: nil

  defp encode_network_id(nid) do
    case nid do
      :testnet -> 0
      :mainnet -> 1
      _ -> nil
    end
  end

  def decode(tx_body) when is_map(tx_body) do
    certificates =
      tx_body[4]
      |> extract_value!()
      |> maybe(nil, fn certs ->
        Enum.map(certs, &Certificate.decode/1)
      end)

    inputs =
      tx_body[0]
      |> extract_value!()
      |> Enum.map(&OutputReference.from_cbor/1)

    %__MODULE__{
      inputs: inputs,
      outputs: Enum.map(tx_body[1], &Output.from_cbor/1),
      fee: Asset.from_lovelace(tx_body[2]),
      ttl: tx_body[3],
      certificates: certificates,
      withdrawals: withdrawal_from_cbor(tx_body[5]),
      auxiliary_data_hash: extract_value!(tx_body[7]),
      validaty_interval_start: tx_body[8],
      mint: maybe(tx_body[9], nil, &Asset.from_plutus/1) |> Utils.ok_or(nil),
      required_signers:
        maybe(extract_value!(tx_body[14]), nil, fn d ->
          Enum.map(d, &extract_value!/1)
        end),
      script_data_hash: extract_value!(tx_body[11]),
      collateral:
        maybe(extract_value!(tx_body[13]), nil, fn d ->
          Enum.map(d, &OutputReference.from_cbor/1)
        end),
      network_id: decode_netword_id(extract_value!(tx_body[15])),
      collateral_return: maybe(tx_body[16], nil, &Output.from_cbor/1),
      total_collateral: maybe(tx_body[17], nil, &Asset.from_cbor/1),
      reference_inputs:
        maybe(extract_value!(tx_body[18]), nil, fn d ->
          Enum.map(d, &OutputReference.from_cbor/1)
        end)
    }
  end

  defp withdrawal_from_cbor(withdrawals) when is_map(withdrawals) do
    for {k, v} <- withdrawals, into: %{}, do: {extract_value!(k), Asset.from_cbor(v)}
  end

  defp withdrawal_from_cbor(_), do: nil

  def to_cbor(%__MODULE__{} = tx_body) do
    Map.to_list(tx_body)
    |> Enum.reduce(%{}, &do_map_to_cbor/2)
  end

  # Ignore nil values
  defp do_map_to_cbor({_, nil}, acc), do: acc
  # Ignore Empty Values
  defp do_map_to_cbor({_, []}, acc), do: acc
  defp do_map_to_cbor({_, m}, acc) when m == %{}, do: acc
  defp do_map_to_cbor({_, %MapSet{map: m}}, acc) when m == %{}, do: acc
  # Ignore values with script definition
  defp do_map_to_cbor({:__struct__, _}, acc), do: acc

  defp do_map_to_cbor({:inputs, inputs}, acc) do
    inputs
    |> Enum.map(fn i ->
      case i do
        %Input{output_reference: ref} -> OutputReference.to_cbor(ref)
        _ -> OutputReference.to_cbor(i)
      end
    end)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(0, acc)
  end

  defp do_map_to_cbor({:outputs, outputs}, acc) do
    outputs
    |> Enum.map(&Output.to_cbor/1)
    |> Cbor.as_indexed_map(1, acc)
  end

  defp do_map_to_cbor({:fee, fee}, acc) do
    fee
    |> Asset.to_cbor()
    |> Cbor.as_indexed_map(2, acc)
  end

  defp do_map_to_cbor({:ttl, ttl}, acc) do
    Cbor.as_indexed_map(ttl, 3, acc)
  end

  defp do_map_to_cbor({:certificates, certs}, acc) do
    certs
    |> Enum.map(&Certificate.to_cbor/1)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(4, acc)
  end

  defp do_map_to_cbor({:withdrawals, withdrawals}, acc) do
    withdrawal_cbor =
      for {k, v} <- withdrawals, into: %{}, do: {Cbor.as_byte(k), Asset.to_cbor(v)}

    Cbor.as_indexed_map(withdrawal_cbor, 5, acc)
  end

  defp do_map_to_cbor({:auxiliary_data_hash, aux_data_hash}, acc) do
    aux_data_hash
    |> Cbor.as_byte()
    |> Cbor.as_indexed_map(7, acc)
  end

  defp do_map_to_cbor({:validaty_interval_start, slot}, acc) do
    Cbor.as_indexed_map(slot, 8, acc)
  end

  defp do_map_to_cbor({:mint, mint_info}, acc) when mint_info != %{} do
    mint_info
    |> Asset.to_plutus()
    |> Cbor.as_indexed_map(9, acc)
  end

  defp do_map_to_cbor({:script_data_hash, script_data_hash}, acc) do
    script_data_hash
    |> Cbor.as_byte()
    |> Cbor.as_indexed_map(11, acc)
  end

  defp do_map_to_cbor({:collateral, collateral}, acc) do
    collateral
    |> Enum.map(&OutputReference.to_cbor/1)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(13, acc)
  end

  defp do_map_to_cbor({:required_signers, required_signers}, acc) do
    required_signers
    |> Enum.map(&Cbor.as_byte/1)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(14, acc)
  end

  defp do_map_to_cbor({:network_id, network_id}, acc) do
    network_id
    |> encode_network_id()
    |> Cbor.as_indexed_map(15, acc)
  end

  defp do_map_to_cbor({:collateral_return, collateral_return}, acc) do
    collateral_return
    |> Output.to_cbor()
    |> Cbor.as_indexed_map(16, acc)
  end

  defp do_map_to_cbor({:total_collateral, total_collateral}, acc) do
    total_collateral
    |> Asset.to_cbor()
    |> Cbor.as_indexed_map(17, acc)
  end

  defp do_map_to_cbor({:reference_inputs, ref_inputs}, acc) do
    ref_inputs
    |> Enum.map(&OutputReference.to_cbor/1)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(18, acc)
  end
end
