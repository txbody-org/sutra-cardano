defmodule Sutra.Cardano.Transaction.Witness do
  @moduledoc """
    Cardano Transaction Witness
  """

  use TypedStruct

  require Sutra.Cardano.Script
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Data.Cbor
  alias Sutra.Data.Plutus
  alias Sutra.Utils

  alias __MODULE__.{PlutusData, Redeemer, VkeyWitness}

  import Sutra.Data.Cbor, only: [extract_value!: 1]
  import Sutra.Utils, only: [maybe: 3]

  defstruct vkey_witness: [], script_witness: [], redeemer: [], plutus_data: []

  @type t() :: %__MODULE__{
          vkey_witness: [VkeyWitness.t()],
          script_witness: [Script.t() | NativeScript.t()],
          redeemer: [Redeemer.t()],
          plutus_data: [PlutusData.t()]
        }

  typedstruct(module: VkeyWitness) do
    field(:vkey, String.t())
    field(:signature, String.t())
  end

  typedstruct(module: PlutusData) do
    field(:value, Plutus.t())
  end

  typedstruct(module: Redeemer) do
    @type redeemer_tag() :: :spend | :mint | :cert | :reward | :vote | :propose

    field(:tag, redeemer_tag())
    field(:index, integer())
    field(:data, Plutus.t())
    field(:exunits, {integer(), integer()})

    def decode_tag!(0), do: :spend
    def decode_tag!(1), do: :mint
    def decode_tag!(2), do: :cert
    def decode_tag!(3), do: :reward
    def decode_tag!(4), do: :vote
    def decode_tag!(5), do: :propose
    def decode_tag!(n), do: raise("Invalid redeemer tag: #{n}")

    def encode_tag(tag) do
      case tag do
        :spend -> 0
        :mint -> 1
        :cert -> 2
        :reward -> 3
        :vote -> 4
        :propose -> 5
      end
    end
  end

  def from_cbor(cbor) when is_binary(cbor) do
    with {:ok, decoded, _} <- CBOR.decode(cbor) do
      from_cbor(decoded)
    end
  end

  def from_cbor(witness_cbor) do
    witness =
      Enum.reduce(Cbor.extract_value!(witness_cbor), %{}, fn w, acc ->
        decoded_val = decode(w)

        key =
          case hd(decoded_val) do
            %VkeyWitness{} ->
              :vkey_witness

            %Script{} ->
              :script_witness

            %Redeemer{} ->
              :redeemer

            %PlutusData{} ->
              :plutus_data
          end

        prev_val = Map.get(acc, key, [])
        Map.put(acc, key, prev_val ++ decoded_val)
      end)

    struct!(__MODULE__, witness)
  end

  def decode({0, %CBOR.Tag{tag: 258, value: vkey_witnesses}}), do: decode({0, vkey_witnesses})

  def decode({0, vkey_witnesses}) do
    Enum.map(vkey_witnesses, fn [%CBOR.Tag{} = vkey, %CBOR.Tag{} = signature] ->
      %VkeyWitness{vkey: vkey.value, signature: signature.value}
    end)
  end

  def decode({1, native_scripts}) do
    Enum.map(extract_value!(native_scripts), &NativeScript.from_witness_set/1)
  end

  def decode({script_type, script_value}) when script_type in [3, 6, 7] do
    [
      %Script{
        script_type: Script.decode_script_type!(script_type),
        data:
          script_value
          |> extract_value!()
          |> Utils.safe_head()
          |> extract_value!()
      }
    ]
  end

  def decode({5, redeemer_witnesses}) when is_map(redeemer_witnesses) do
    Enum.map(redeemer_witnesses, fn {[tag, index], [data, [mem, exec]]} ->
      %Redeemer{
        tag: __MODULE__.Redeemer.decode_tag!(tag),
        index: index,
        data: Plutus.decode(data) |> Utils.ok_or(data),
        exunits: {mem, exec}
      }
    end)
  end

  def decode({5, [tag, index, data, [mem, exec]]}) do
    %Redeemer{
      tag: __MODULE__.Redeemer.decode_tag!(tag),
      index: index,
      data: Plutus.decode(data) |> Utils.ok_or(data),
      exunits: {mem, exec}
    }
  end

  def decode({5, redeemer_witnesses}) when is_list(redeemer_witnesses) do
    Enum.map(redeemer_witnesses, fn [tag, index, data, [mem, exec]] ->
      %Redeemer{
        tag: __MODULE__.Redeemer.decode_tag!(tag),
        index: index,
        data: Plutus.decode(data) |> Utils.ok_or(data),
        exunits: {mem, exec}
      }
    end)
  end

  def decode({4, plutus_data}) do
    [%PlutusData{value: extract_value!(plutus_data) |> Plutus.decode!()}]
  end

  def decode({red_type, redeemer_info}) do
    raise """
      Not Implemented Redeemer Type: \n  #{inspect(red_type)}

      Redeemer Info: \n  #{inspect(redeemer_info)}

    """
  end

  @doc """
    Encode WitnessSet to CBOR
    https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/conway/impl/cddl-files/conway.cddl#L489


    transaction_witness_set = {? 0 : nonempty_set<vkeywitness>
                          , ? 1 : nonempty_set<native_script>
                          , ? 2 : nonempty_set<bootstrap_witness>
                          , ? 3 : nonempty_set<plutus_v1_script>
                          , ? 4 : nonempty_set<plutus_data>
                          , ? 5 : redeemers
                          , ? 6 : nonempty_set<plutus_v2_script>
                          , ? 7 : nonempty_set<plutus_v3_script>}



    iex> to_cbor([vkey_witness, native_script, redeemer, plutus_data])
    %{0 => vkey_witness_cbor, 1 => script_witness_cbor, 5 => redeemer_cbor, 4 => plutus_data_cbor}

  """
  def to_cbor(tx_witness_sets) when is_list(tx_witness_sets) do
    Enum.reduce(tx_witness_sets, %{}, &do_encode_witness_to_cbor/2)
  end

  def to_cbor(%__MODULE__{} = witness) do
    to_cbor(
      witness.vkey_witness ++ witness.script_witness ++ witness.redeemer ++ witness.plutus_data
    )
  end

  # Encode VkeyWitness to CBOR
  # {0 : nonempty_set<vkeywitness}
  defp do_encode_witness_to_cbor(%VkeyWitness{} = vkey_witness, acc) do
    val =
      [Cbor.as_byte(vkey_witness.vkey), Cbor.as_byte(vkey_witness.signature)]

    Map.get(acc, 0)
    |> extract_value!()
    |> Utils.maybe([val], &[val | &1])
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(0, acc)
  end

  # Encode Native Script to CBOR
  # {1 : nonempty_set<nativescript>}
  defp do_encode_witness_to_cbor(script, acc) when Script.is_native_script(script) do
    cbor_witness = NativeScript.to_witness_set(script)

    Map.get(acc, 1)
    |> extract_value!()
    |> Utils.safe_append([cbor_witness])
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(1, acc)
  end

  # Encode Plutus Script to CBOR
  # {3, 6, 7 : nonempty_set<plutusdata>}
  defp do_encode_witness_to_cbor(%Script{} = script_witness, acc) do
    script_indx = Script.encode_script_type(script_witness.script_type)
    values = Utils.safe_base16_decode(script_witness.data) |> Cbor.as_byte()

    acc
    |> Map.get(script_indx)
    |> extract_value!()
    |> Utils.maybe([values], &(&1 ++ [values]))
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(script_indx, acc)
  end

  # Encode Redeemer to CBOR
  #
  # redeemer_tag = 0 / 1 / 2 / 3 / 4 / 5
  # {+ [tag : redeemer_tag , index : uint .size 4] =>
  #              [data : plutus_data , ex_units : ex_units]}
  #
  defp do_encode_witness_to_cbor(%Redeemer{exunits: {mem, steps}} = redeemer, acc) do
    redeemer_key = [Redeemer.encode_tag(redeemer.tag), redeemer.index]
    redeemer_val = [redeemer.data, [mem, steps]]

    Map.get(acc, 5, %{})
    |> Map.put(redeemer_key, redeemer_val)
    |> Cbor.as_indexed_map(5, acc)
  end

  # Encode plutus Data Witness
  #
  #
  defp do_encode_witness_to_cbor(%PlutusData{value: value}, acc) do
    Map.get(acc, 4)
    |> extract_value!()
    |> maybe([value], &[&1 | value])
    |> Cbor.as_nonempty_set()
    |> Cbor.as_indexed_map(4, acc)
  end

  def init_redeemer(index, data, tag \\ :mint),
    do: %Redeemer{index: index, tag: tag, data: data, exunits: {0, 0}}

  @doc """
    Checks if signature provided in witness is signed by correct Signing Key

    ## Examples

      iex> verify_signature(%VkeyWitness{}, valid_payload)
      :ok

      iex> verify_signature(%VkeyWitness{signature: invalid_signature}, payload)
      {:error, :INVALID_SIGNATURE}

      iex> verify_signature(invalid_witness, payload)
      {:error, :INVALID_VKEY_WITNESS}
  """
  def verify_signature(%__MODULE__.VkeyWitness{vkey: v_key, signature: sig}, tx_id)
      when is_binary(tx_id) and byte_size(v_key) == 32 and byte_size(sig) == 64 do
    tx_id_byte = Cbor.as_byte(tx_id).value

    if :crypto.verify(:eddsa, :none, tx_id_byte, sig, [v_key, :ed25519]),
      do: :ok,
      else: {:error, :INVALID_SIGNATURE}
  end

  def verify_signature?(_), do: {:error, :INVALID_VKEY_WITNESS}
end
