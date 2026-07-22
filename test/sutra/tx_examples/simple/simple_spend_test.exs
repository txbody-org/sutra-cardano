defmodule Sutra.TxExamples.Simple.SimpleSpendTest do
  @moduledoc false

  use Sutra.PrivnetTest

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Provider.Yaci

  import Sutra.Test.Support.BlueprintSupport

  describe "Simple Spend from script" do
    test "collects inputs from script if guessed number is correct" do
      with_new_wallet(fn %{signing_key: signing_key, address: addr} ->
        script =
          get_simple_script("simple.simple.spend")
          |> Script.apply_params([Base.encode16("some-params-guess")])
          |> Script.new(:plutus_v3)

        script_addr = Address.from_script(script, :preprod)

        place_tx_id =
          Sutra.new_tx()
          |> Sutra.add_output(
            script_addr,
            Asset.from_lovelace(2_000_000),
            {:inline_datum, 100}
          )
          |> Sutra.build_tx!(wallet_address: addr)
          |> Sutra.sign_tx([
            signing_key,
            "ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"
          ])
          |> Sutra.submit_tx()

        await_tx(place_tx_id)

        script_guess_utxo = Yaci.utxos_at_tx_refs(["#{place_tx_id}#0"])

        spend_tx_id =
          Sutra.new_tx()
          # spending with redeemer 100 which matches with datum set in place Tx
          |> Sutra.add_input(script_guess_utxo, witness: script, redeemer: 100)
          |> Sutra.build_tx!(wallet_address: addr)
          |> Sutra.sign_tx([signing_key])
          |> Sutra.submit_tx()

        await_tx(spend_tx_id)

        # should return nil for place_tx_id since it is already spent
        place_utxo =
          Yaci.utxos_at_addresses([script_addr])
          |> Enum.find(fn %Input{output_reference: oref} ->
            oref.transaction_id == place_tx_id
          end)

        assert is_nil(place_utxo)
      end)
    end
  end

  describe "Spend with guards" do
    # The script guard uses a RequireGuard native script (type 6), Dijkstra-only.
    @tag :dijkstra
    test "attaches both a pubkeyhash guard and a script guard" do
      with_new_wallet(fn %{signing_key: signing_key, address: addr} ->
        to_address = random_address()

        # A native script that only validates when the wallet key is present in
        # the tx `guards` field, exercised here alongside a plain pubkeyhash guard.
        guard_script = guard_native_script(addr)

        tx =
          Sutra.new_tx()
          |> Sutra.add_output(to_address, Asset.from_lovelace(2_000_000))
          # pubkeyhash guard (also satisfies the script guard's RequireGuard)
          |> Sutra.add_guard(addr)
          # script guard: derives the script credential and attaches the script
          |> Sutra.add_guard(guard_script)
          |> Sutra.build_tx!(wallet_address: addr)

        guards = tx.tx_body.guards

        submit_tx_id =
          tx
          |> Sutra.sign_tx([signing_key])
          |> Sutra.submit_tx()

        IO.inspect(submit_tx_id)
        await_tx(submit_tx_id)

        assert %Credential{credential_type: :vkey} =
                 Enum.find(guards, &(&1.credential_type == :vkey))

        assert %Credential{credential_type: :script, hash: script_hash} =
                 Enum.find(guards, &(&1.credential_type == :script))

        assert script_hash == Script.hash_script(guard_script)

        assert Asset.from_lovelace(2_000_000) == Yaci.balance_of(to_address)
      end)
    end
  end
end
