defmodule Sutra.Cardano.Transaction.TxBody do
  @moduledoc """
    Cardano Transaction Body
  """
  alias CBOR.Utils
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov
  alias Sutra.Cardano.Gov.ProposalProcedure
  alias Sutra.Cardano.Transaction.AccountBalanceInterval
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
    field(:withdrawals, %{})
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
    # -- (14) DEPRECATED: Dijkstra replaces this with `guards` below. No
    # longer populated on decode, and ignored on encode.
    field(:required_signers, [String.t()])
    # -- (14) guards = nonempty_set<addr_keyhash> / nonempty_oset<credential>
    # Both wire alternatives normalize to a list of Credential.t() here; on
    # encode we emit the compact addr_keyhash-only set when every entry is a
    # vkey credential, else the full credential oset.
    field(:guards, [Credential.t()])
    # -- (15)
    field(:network_id, :string)
    # -- (16)
    field(:collateral_return, Output.t())
    # -- (17)
    field(:total_collateral, :integer)
    # -- (18)
    field(:reference_inputs, [OutputReference.t()])

    # --- New Fields in Conway Era
    # -- (19) %{Gov.Voter.t() => %{OutputReference.t() => Gov.VotingProcedure.t()}}
    field(:voting_procedures, map())
    # -- (20)
    field(:proposal_procedures, any())
    # -- (21)
    field(:current_treasury_value, :integer)
    # -- (22)
    field(:treasury_donation, :integer)

    # --- New Fields in Dijkstra Era
    # -- (23) sub_transactions: not yet supported
    # -- (25) %{reward_account :: String.t() => Asset.t()}
    field(:direct_deposits, %{})
    # -- (26) %{Credential.t() => AccountBalanceInterval.t()}
    field(:account_balance_intervals, %{})
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
      guards: decode_guards(tx_body[14]),
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
        end),
      voting_procedures: Gov.decode_voting_procedures(tx_body[19]),
      proposal_procedures: decode_proposal_procedures(tx_body[20]),
      direct_deposits: withdrawal_from_cbor(tx_body[25]),
      account_balance_intervals: AccountBalanceInterval.decode_all(tx_body[26])
    }
  end

  defp withdrawal_from_cbor(withdrawals) when is_map(withdrawals) do
    for {k, v} <- withdrawals, into: %{}, do: {extract_value!(k), Asset.from_cbor(v)}
  end

  defp withdrawal_from_cbor(_), do: nil

  # proposal_procedures = nonempty_oset<proposal_procedure>
  defp decode_proposal_procedures(nil), do: nil

  defp decode_proposal_procedures(procedures_cbor) do
    procedures_cbor
    |> extract_value!()
    |> Enum.map(&ProposalProcedure.decode/1)
  end

  # guards = nonempty_set<addr_keyhash> / nonempty_oset<credential>
  #
  # Pre-Dijkstra transactions (and the addr_keyhash-only guards alternative)
  # encode entries as raw keyhashes; the credential alternative encodes
  # entries as [cred_type, hash]. Both normalize to Credential.t() here.
  defp decode_guards(nil), do: nil

  defp decode_guards(guards_cbor) do
    guards_cbor
    |> extract_value!()
    |> Enum.map(&decode_guard_entry/1)
  end

  defp decode_guard_entry([cred_type, hash]) when cred_type in [0, 1] do
    Address.credential_from_cbor([cred_type, hash])
  end

  defp decode_guard_entry(key_hash) do
    %Credential{credential_type: :vkey, hash: extract_value!(key_hash)}
  end

  defp encode_guards(guards) do
    if Enum.all?(guards, &(&1.credential_type == :vkey)) do
      guards |> Enum.map(&Cbor.as_byte(&1.hash))
    else
      Enum.map(guards, &Address.credential_to_cbor/1)
    end
    |> Cbor.as_nonempty_set()
  end

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
      for {k, v} <- withdrawals,
          into: %{},
          do: {Cbor.as_byte(k), Asset.to_cbor(v)}

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

  # DEPRECATED: Dijkstra removes required_signers in favor of `guards`
  # (encoded below). Kept as a no-op so setting it doesn't raise.
  defp do_map_to_cbor({:required_signers, _}, acc), do: acc

  defp do_map_to_cbor({:guards, guards}, acc) do
    guards
    |> encode_guards()
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
    |> Enum.map(fn r ->
      case r do
        %Input{} -> OutputReference.to_cbor(r.output_reference)
        _ -> OutputReference.to_cbor(r)
      end
    end)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(18, acc)
  end

  defp do_map_to_cbor({:voting_procedures, voting_procedures}, acc) do
    voting_procedures
    |> Gov.encode_voting_procedures()
    |> Cbor.as_indexed_map(19, acc)
  end

  defp do_map_to_cbor({:proposal_procedures, proposal_procedures}, acc) do
    proposal_procedures
    |> Enum.map(&ProposalProcedure.to_cbor/1)
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(20, acc)
  end

  defp do_map_to_cbor({:direct_deposits, direct_deposits}, acc) do
    direct_deposits_cbor =
      for {k, v} <- direct_deposits,
          into: %{},
          do: {Cbor.as_byte(k), Asset.to_cbor(v)}

    Cbor.as_indexed_map(direct_deposits_cbor, 25, acc)
  end

  defp do_map_to_cbor({:account_balance_intervals, account_balance_intervals}, acc) do
    account_balance_intervals
    |> AccountBalanceInterval.encode_all()
    |> Cbor.as_indexed_map(26, acc)
  end
end
