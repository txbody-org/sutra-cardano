defmodule Sutra.Cardano.Script.NativeScript do
  @moduledoc """
   Cardano Native Script
  """

  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Data.Cbor
  alias Sutra.Utils

  @type t() ::
          __MODULE__.ScriptPubkey.t()
          | __MODULE__.ScriptAll.t()
          | __MODULE__.ScriptAny.t()
          | __MODULE__.ScriptNOfK.t()
          | __MODULE__.ScriptInvalidBefore.t()
          | __MODULE__.ScriptInvalidHereafter.t()
          | __MODULE__.ScriptRequireGuard.t()

  use TypedStruct

  typedstruct(module: ScriptPubkey) do
    field(:pubkey_hash, String.t())
  end

  typedstruct(module: ScriptAll) do
    field(:scripts, [String.t()])
  end

  typedstruct(module: ScriptAny) do
    field(:scripts, [String.t()])
  end

  typedstruct(module: ScriptNOfK) do
    field(:n, integer())
    field(:scripts, [NativeScript.t()])
  end

  typedstruct(module: ScriptInvalidBefore) do
    field(:slot, integer())
  end

  typedstruct(module: ScriptInvalidHereafter) do
    field(:slot, integer())
  end

  typedstruct(module: ScriptRequireGuard) do
    field(:credential, Credential.t())
  end

  def from_witness_set([0, pubkey]) do
    %ScriptPubkey{pubkey_hash: Cbor.extract_value!(pubkey)}
  end

  def from_witness_set([1, native_scripts]) do
    %ScriptAll{scripts: Enum.map(native_scripts, &from_witness_set/1)}
  end

  def from_witness_set([2, native_scripts]) do
    %ScriptAny{scripts: Enum.map(native_scripts, &from_witness_set/1)}
  end

  def from_witness_set([3, n, native_scripts]) do
    %ScriptNOfK{n: n, scripts: Enum.map(native_scripts, &from_witness_set/1)}
  end

  def from_witness_set([4, slot]) do
    %ScriptInvalidBefore{slot: slot}
  end

  def from_witness_set([5, slot]) do
    %ScriptInvalidHereafter{slot: slot}
  end

  def from_witness_set([6, credential]) do
    %ScriptRequireGuard{credential: decode_credential(credential)}
  end

  def to_witness_set(%ScriptPubkey{pubkey_hash: pubkey}) do
    [0, Cbor.as_byte(pubkey)]
  end

  def to_witness_set(%ScriptAll{scripts: scripts}) do
    [1, Enum.map(scripts, &to_witness_set/1)]
  end

  def to_witness_set(%ScriptAny{scripts: scripts}) do
    [2, Enum.map(scripts, &to_witness_set/1)]
  end

  def to_witness_set(%ScriptNOfK{n: n, scripts: scripts}) do
    [3, n, Enum.map(scripts, &to_witness_set/1)]
  end

  def to_witness_set(%ScriptInvalidBefore{slot: slot}) do
    [4, slot]
  end

  def to_witness_set(%ScriptInvalidHereafter{slot: slot}) do
    [5, slot]
  end

  def to_witness_set(%ScriptRequireGuard{credential: credential}) do
    [6, encode_credential(credential)]
  end

  def from_cbor(cbor_hex) when is_binary(cbor_hex) do
    {:ok, cbor, _} =
      cbor_hex
      |> Utils.safe_base16_decode()
      |> CBOR.decode()

    from_witness_set(cbor)
  end

  def from_json(script) when is_map(script) do
    do_parse_from_json(script)
  end

  def to_script(native_script) do
    native_script
    |> to_witness_set()
    |> Cbor.encode_hex()
    |> Script.new(:native)
  end

  defp do_parse_from_json(%{"type" => "all", "scripts" => scripts}) when is_list(scripts) do
    %__MODULE__.ScriptAll{scripts: Enum.map(scripts, &do_parse_from_json/1)}
  end

  defp do_parse_from_json(%{"type" => "any", "scripts" => scripts}) when is_list(scripts) do
    %__MODULE__.ScriptAny{scripts: Enum.map(scripts, &do_parse_from_json/1)}
  end

  defp do_parse_from_json(%{"type" => "atLeast", "required" => n, "scripts" => scripts})
       when is_list(scripts) and is_integer(n) do
    %__MODULE__.ScriptNOfK{scripts: Enum.map(scripts, &do_parse_from_json/1), n: n}
  end

  defp do_parse_from_json(%{"type" => "after", "slot" => slot_no}) when is_integer(slot_no) do
    %__MODULE__.ScriptInvalidBefore{slot: slot_no}
  end

  defp do_parse_from_json(%{"type" => "before", "slot" => slot_no}) when is_integer(slot_no) do
    %__MODULE__.ScriptInvalidHereafter{slot: slot_no}
  end

  defp do_parse_from_json(%{"type" => "sig", "keyHash" => pubkey_hash})
       when is_binary(pubkey_hash) do
    %__MODULE__.ScriptPubkey{pubkey_hash: pubkey_hash}
  end

  defp do_parse_from_json(%{"type" => "guard", "keyHash" => key_hash})
       when is_binary(key_hash) do
    %__MODULE__.ScriptRequireGuard{
      credential: %Credential{credential_type: :vkey, hash: key_hash}
    }
  end

  defp do_parse_from_json(%{"type" => "guard", "scriptHash" => script_hash})
       when is_binary(script_hash) do
    %__MODULE__.ScriptRequireGuard{
      credential: %Credential{credential_type: :script, hash: script_hash}
    }
  end

  defp decode_credential([cred_type, hash]) do
    credential_type = if cred_type == 0, do: :vkey, else: :script
    %Credential{credential_type: credential_type, hash: Cbor.extract_value!(hash)}
  end

  defp encode_credential(%Credential{} = credential) do
    credential_type = if credential.credential_type == :vkey, do: 0, else: 1
    [credential_type, Cbor.as_byte(credential.hash)]
  end
end
