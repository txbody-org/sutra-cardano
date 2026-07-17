defmodule Sutra.Cardano.Common.DrepTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Sutra.Cardano.Common.Drep

  @key_hash "5064b671634d14cb8d543e71dd8eb437a47efb47b0b22882866c420d"
  @script_hash "99e21871b90d685cb26c4171169a54e5ed4f26f39dfc161b35fb8112"

  describe "to_cbor/1" do
    test "encodes key_hash drep" do
      assert [0, %CBOR.Tag{tag: :bytes}] = Drep.key_hash_drep(@key_hash) |> Drep.to_cbor()
    end

    # Regression: `to_cbor/1` matched a misspelled `:sctipt_hash` atom, so any
    # genuine `:script_hash` drep raised CaseClauseError on encode.
    test "encodes script_hash drep" do
      assert [1, %CBOR.Tag{tag: :bytes}] = Drep.script_drep(@script_hash) |> Drep.to_cbor()
    end

    test "encodes abstain and no_confidence" do
      assert [2] = Drep.abstain() |> Drep.to_cbor()
      assert [3] = Drep.no_confidence() |> Drep.to_cbor()
    end
  end

  describe "round trip to_cbor/1 -> from_cbor/1" do
    test "script_hash drep" do
      drep = Drep.script_drep(@script_hash)
      assert drep == drep |> Drep.to_cbor() |> Drep.from_cbor()
    end

    test "key_hash drep" do
      drep = Drep.key_hash_drep(@key_hash)
      assert drep == drep |> Drep.to_cbor() |> Drep.from_cbor()
    end
  end
end
