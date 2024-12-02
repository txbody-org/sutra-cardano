defmodule Sutra.Cardano.Script.NativeScript do
  @moduledoc """
   Cardano Native Script 
  """
  alias Sutra.Cardano.Script.NativeScript

  @type t() ::
          ScriptPubkey.t()
          | ScriptAll.t()
          | ScriptAny.t()
          | ScriptNOfK.t()
          | ScriptInvalidBefore.t()
          | ScriptInvalidHereafter.t()

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

  def from_witness_set([0, pubkey]) do
    %ScriptPubkey{pubkey_hash: pubkey}
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

  def to_witness_set(%ScriptPubkey{pubkey_hash: pubkey}) do
    [0, pubkey]
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
end
