defmodule Sutra.Cardano.Transaction.Witness do
  @moduledoc """
    Cardano Transaction Witness
  """

  use TypedStruct

  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Data.Plutus
  alias Sutra.Utils

  import Sutra.Data.Cbor, only: [extract_value!: 1]

  @type t() :: __MODULE__.VkeyWitness.t() | __MODULE__.Redeemer.t()

  typedstruct(module: VkeyWitness) do
    field(:vkey, String.t())
    field(:signature, String.t())
  end

  typedstruct(module: Redeemer) do
    @type redeemer_tag() :: :spend | :mint | :cert | :reward | :vote | :propose

    field(:tag, redeemer_tag())
    field(:index, integer())
    field(:data, Plutus.t())
    field(:exunits, {integer(), integer()})
    field(:is_legacy, boolean(), default: false)

    def decode_tag!(0), do: :spend
    def decode_tag!(1), do: :mint
    def decode_tag!(2), do: :cert
    def decode_tag!(3), do: :reward
    def decode_tag!(4), do: :vote
    def decode_tag!(5), do: :propose
    def decode_tag!(n), do: raise("Invalid redeemer tag: #{n}")
  end

  typedstruct(module: ScriptWitness) do
    @type script_type() ::
            :native_script
            | :plutus_v1
            | :plutus_v2
            | :plutus_v3

    field(:script_type, script_type())
    field(:data, String.t())

    def decode_script_type!(1), do: :native
    def decode_script_type!(3), do: :plutus_v1
    def decode_script_type!(6), do: :plutus_v2
    def decode_script_type!(7), do: :plutus_v3
  end

  def decode({0, %CBOR.Tag{tag: 258, value: vkey_witnesses}}), do: decode({0, vkey_witnesses})

  def decode({0, vkey_witnesses}) do
    Enum.map(vkey_witnesses, fn [vkey, signature] ->
      %VkeyWitness{vkey: extract_value!(vkey), signature: extract_value!(signature)}
    end)
  end

  def decode({1, native_scripts}) do
    [
      %ScriptWitness{
        script_type: :native,
        data: Enum.map(extract_value!(native_scripts), &NativeScript.from_witness_set/1)
      }
    ]
  end

  def decode({script_type, script_value}) when script_type in [3, 6, 7] do
    [
      %ScriptWitness{
        script_type: ScriptWitness.decode_script_type!(script_type),
        data: extract_value!(script_value) |> Enum.map(&extract_value!/1)
      }
    ]
  end

  def decode({5, redeemer_witnesses}) when is_map(redeemer_witnesses) do
    Enum.map(redeemer_witnesses, fn {[tag, index], [data, [mem, exec]]} ->
      %Redeemer{
        tag: __MODULE__.Redeemer.decode_tag!(tag),
        index: index,
        data: Plutus.decode(data) |> Utils.ok_or(data),
        exunits: {mem, exec},
        is_legacy: true
      }
    end)
  end

  def decode({5, redeemer_witnesses}) when is_list(redeemer_witnesses) do
    Enum.map(redeemer_witnesses, fn [tag, index, data, [mem, exec]] ->
      %Redeemer{
        tag: __MODULE__.Redeemer.decode_tag!(tag),
        index: index,
        data: Plutus.decode(data) |> Utils.ok_or(data),
        exunits: {mem, exec},
        is_legacy: true
      }
    end)
  end

  def decode({red_type, redeemer_info}) do
    raise """
      Not Implemented Redeemer Type: \n  #{inspect(red_type)}

      Redeemer Info: \n  #{inspect(redeemer_info)}

    """
  end
end
