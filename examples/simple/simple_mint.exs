# Setup Provider
Code.eval_file("examples/setup_provider.exs")

# Check required Env Vars for this script
address = System.get_env("TEST_ADDRESS")
signing_key = System.get_env("TEST_SIGNING_KEY")

if is_nil(address) or is_nil(signing_key) do
  IO.puts("Error: TEST_ADDRESS and TEST_SIGNING_KEY must be set.")
  System.halt(1)
end

defmodule Sutra.Examples.Advance.AlwaysSucceed do
  @moduledoc false

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Data

  def blueprint, do: File.read!("./blueprint.json") |> :elixir_json.decode()

  def get_script(title) do
    blueprint()
    |> Map.get("validators", [])
    |> Enum.find(fn v -> v["title"] == title end)
    |> Map.get("compiledCode")
  end

  def run(user_address, signing_key) do
    simple_mint_script =
      get_script("simple.simple.mint")
      |> Script.apply_params([Base.encode16("some-params", case: :lower)])
      |> Script.new(:plutus_v3)

    mint_script_address = Address.from_script(simple_mint_script, :preprod)

    # user_utxos = Provider.utxos_at_addresses([user_address]) |> IO.inspect()

    out_token_name = Base.encode16("SUTRA-SDK-TEST", case: :lower)
    policy_id = Script.hash_script(simple_mint_script)

    out_value =
      Asset.zero()
      |> Asset.add(policy_id, out_token_name, 100)

    # Use current time
    current_posix_time = System.os_time(:millisecond)

    tx_id =
      Sutra.new_tx()
      |> Sutra.attach_metadata(123, "Test Sutra TX")
      |> Sutra.mint_asset(policy_id, %{out_token_name => 100}, simple_mint_script, Data.void())
      |> Sutra.add_output(mint_script_address, out_value, {:inline_datum, 58})
      |> Sutra.add_output(
        Address.from_bech32(user_address),
        %{"lovelace" => 10_000},
        {:datum_hash, 4}
      )
      |> Sutra.valid_from(current_posix_time - 5 * 60 * 1000)
      |> Sutra.valid_to(current_posix_time + 20 * 60 * 1000)
      |> Sutra.build_tx!(wallet_address: [Address.from_bech32(user_address)])
      |> Sutra.sign_tx([signing_key])
      |> Sutra.submit_tx()

    IO.puts(" Tx submitted with : #{tx_id}")
  end
end

Sutra.Examples.Advance.AlwaysSucceed.run(address, signing_key)
