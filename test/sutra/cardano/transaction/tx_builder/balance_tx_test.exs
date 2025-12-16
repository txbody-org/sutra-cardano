defmodule Sutra.Cardano.Transaction.TxBuilder.BalanceTxTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset

  import Sutra.Cardano.Transaction.TxBuilder
  import Sutra.Test.Support.BuilderSupport

  @addr1 "addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5pnz75xxcrzqf96k"
  @change_addr "addr1w8phkx6acpnf78fuvxn0mkew3l0fd058hzquvz7w36x4gtcyjy7wx"

  defmodule DummyProvider do
    @behaviour Sutra.Provider
    def utxos_at(_), do: []
    def utxos_at_refs(_), do: []
    def protocol_params, do: %{}

    def slot_config,
      do: %Sutra.SlotConfig{zero_time: 1_596_059_091_000, zero_slot: 4_492_800, slot_length: 1000}

    def network, do: :testnet
    def datum_of(_), do: %{}
    def submit_tx(_), do: ""
    def tx_cbor(_), do: ""
  end

  setup do
    # Setup default protocol params
    pp = sample_protocol_params()
    {:ok, pp: pp}
  end

  describe "balance_tx" do
    test "balances simple lovelace transaction", %{pp: pp} do
      wallet_utxos = [
        input(Asset.from_lovelace(5_000_000)),
        input(Asset.from_lovelace(3_000_000))
      ]

      # Send 2 ADA
      tx =
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_output(Address.from_bech32(@addr1), Asset.from_lovelace(2_000_000))
        |> build_tx!(wallet_utxos: wallet_utxos, change_address: @change_addr)

      # Should select 5 ADA input (LargestFirst)
      assert length(tx.tx_body.inputs) == 1
      assert Asset.lovelace_of(hd(tx.tx_body.inputs).output.value) == 5_000_000

      # Check outputs: 1 payment + 1 change
      assert length(tx.tx_body.outputs) == 2

      # Verify change output
      change_output = List.last(tx.tx_body.outputs)
      assert change_output.address == Address.from_bech32(@change_addr)
      # Change should be roughly 5 - 2 - fee
      change_lovelace = Asset.lovelace_of(change_output.value)
      assert change_lovelace < 3_000_000
      assert change_lovelace > 2_800_000
    end

    test "balances transaction with native tokens", %{pp: pp} do
      wallet_utxos = [
        input(Asset.from_lovelace(2_000_000) |> Asset.add("policy", "token", 100)),
        input(Asset.from_lovelace(5_000_000))
      ]

      # Send 50 tokens
      tx =
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_output(
          Address.from_bech32(@addr1),
          Asset.from_lovelace(1_500_000) |> Asset.add("policy", "token", 50)
        )
        |> build_tx!(wallet_utxos: wallet_utxos, change_address: @change_addr)

      # Should select the token input
      assert Enum.any?(tx.tx_body.inputs, fn i ->
               get_in(i.output.value, ["policy", "token"]) == 100
             end)

      # Check change has remaining tokens
      change_output = List.last(tx.tx_body.outputs)
      assert get_in(change_output.value, ["policy", "token"]) == 50
    end

    test "fails when insufficient funds", %{pp: pp} do
      wallet_utxos = [
        input(Asset.from_lovelace(1_000_000))
      ]

      # Try to send 2 ADA
      assert_raise RuntimeError, fn ->
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_output(Address.from_bech32(@addr1), Asset.from_lovelace(2_000_000))
        |> build_tx!(wallet_utxos: wallet_utxos, change_address: @change_addr)
      end
    end

    test "respects manually added inputs", %{pp: pp} do
      manual_input = input(Asset.from_lovelace(2_000_000))

      wallet_utxos = [
        input(Asset.from_lovelace(5_000_000))
      ]

      # Send 3 ADA. Manual input (2) + Wallet input (5) needed?
      # Or just Wallet input (5) if manual is not enough?
      # If we add manual input, it MUST be in the transaction.

      tx =
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_input([manual_input])
        |> add_output(Address.from_bech32(@addr1), Asset.from_lovelace(3_000_000))
        |> build_tx!(wallet_utxos: wallet_utxos, change_address: @change_addr)

      # Manual input must be present
      assert Enum.any?(tx.tx_body.inputs, fn i -> i == manual_input end)

      # Since 2 < 3 + fee, it should also select the 5 ADA input
      assert length(tx.tx_body.inputs) >= 2
    end

    test "balances transaction with large token inputs and small output", %{pp: pp} do
      # Scenario:
      # Inputs:
      #   1: (policy, token, 1_000_000), lovelace: 1_034_400
      #   2: (policy, token, 1_000_000), lovelace: 1_034_400
      #   3: lovelace: 5_000_000
      # Output:
      #   1: (policy, token, 500), lovelace: 1_305_930
      # Fee: ~668_274

      wallet_utxos = [
        input(Asset.from_lovelace(1_034_400) |> Asset.add("policy", "token", 1_000_000)),
        input(Asset.from_lovelace(1_034_400) |> Asset.add("policy", "token", 1_000_000)),
        input(Asset.from_lovelace(5_000_000))
      ]

      tx =
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_output(
          Address.from_bech32(@addr1),
          Asset.from_lovelace(1_305_930) |> Asset.add("policy", "token", 500)
        )
        |> build_tx!(wallet_utxos: wallet_utxos, change_address: @change_addr)

      # Should select one token input (1M > 500)
      # And potentially the 5 ADA input if 1.03 ADA isn't enough for 1.3 ADA output + fee + change min ADA
      # 1.034400 (input) - 1.305930 (output) = -0.27 ADA deficit immediately.
      # So it MUST select more inputs.
      # LargestFirst for Lovelace will pick the 5 ADA input next.

      assert Enum.any?(tx.tx_body.inputs, fn i ->
               get_in(i.output.value, ["policy", "token"]) == 1_000_000
             end)

      assert Enum.any?(tx.tx_body.inputs, fn i ->
               Asset.lovelace_of(i.output.value) == 5_000_000
             end)

      # Check change
      # Total Input Tokens: 1_000_000
      # Output Tokens: 500
      # Change Tokens: 999_500
      change_output = List.last(tx.tx_body.outputs)
      assert get_in(change_output.value, ["policy", "token"]) == 999_500
    end

    test "balances transaction ensuring min ADA for change output", %{pp: pp} do
      # Update PP to have realistic min ADA cost (Mainnet value)
      pp = %{pp | ada_per_utxo_byte: 4310}

      # Scenario:
      # We have an input that is enough for output + fee, but we need to ensure
      # there is enough left for the change output's min ADA.
      #
      # Output: 1 ADA
      # Fee: ~0.2 ADA (estimated)
      # Min ADA for change (lovelace only): ~1 ADA (with ada_per_utxo_byte: 4310)
      #
      # Wallet UTXO: 2.5 ADA
      #
      # 2.5 - 1.0 (output) - 0.2 (fee) = 1.3 ADA remaining.
      # This should be enough for change min ADA (~1.0).
      #
      # If we had 1.3 ADA input:
      # 1.3 - 1.0 - 0.2 = 0.1 ADA remaining.
      # This is NOT enough for change min ADA. It should fail or require more inputs.

      wallet_utxos = [
        input(Asset.from_lovelace(2_500_000))
      ]

      tx =
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_output(Address.from_bech32(@addr1), Asset.from_lovelace(1_000_000))
        |> build_tx!(wallet_utxos: wallet_utxos, change_address: @change_addr)

      assert length(tx.tx_body.inputs) == 1
      change_output = List.last(tx.tx_body.outputs)
      assert Asset.lovelace_of(change_output.value) > 900_000

      # Now try with insufficient funds for change min ADA
      small_wallet_utxos = [
        input(Asset.from_lovelace(1_300_000))
      ]

      assert_raise RuntimeError, fn ->
        new_tx()
        |> use_provider(DummyProvider)
        |> set_protocol_params(pp)
        |> add_output(Address.from_bech32(@addr1), Asset.from_lovelace(1_000_000))
        |> build_tx!(wallet_utxos: small_wallet_utxos, change_address: @change_addr)
      end
    end
  end
end
