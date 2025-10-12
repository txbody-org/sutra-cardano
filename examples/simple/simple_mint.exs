# Use Provider
Code.eval_file("examples/setup_yaci_provider.exs")

defmodule Sutra.Examples.Advance.AlwaysSucceed do
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Script
  alias Sutra.Data

  import Sutra.Cardano.Transaction.TxBuilder

  def blueprint, do: File.read!("./blueprint.json") |> :elixir_json.decode()

  def get_script(title) do
    blueprint()
    |> Map.get("validators", [])
    |> Enum.find(fn v -> v["title"] == title end)
    |> Map.get("compiledCode")
  end

  def run do
    user_address = "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"

    simple_mint_script =
      get_script("simple.simple.mint")
      |> Script.apply_params([Base.encode16("some-params")])
      |> Script.new(:plutus_v3)

    mint_script_address = Address.from_script(simple_mint_script, :preprod)

    out_token_name = Base.encode16("SUTRA-SDK-TEST")
    policy_id = Script.hash_script(simple_mint_script)

    out_value =
      Asset.zero()
      |> Asset.add(policy_id, out_token_name, 100)

    current_posix_time = System.os_time(:millisecond)

    tx_id =
      new_tx()
      |> attach_metadata(123, "Test Sutra TX")
      |> mint_asset(policy_id, %{out_token_name => 100}, simple_mint_script, Data.void())
      |> add_output(mint_script_address, out_value, {:inline_datum, 58})
      |> add_output(Address.from_bech32(user_address), %{"lovelace" => 10_000}, {:datum_hash, 4})
      |> valid_from(current_posix_time)
      |> valid_to(current_posix_time + 20 * 60 * 1000)
      |> build_tx!(wallet_address: user_address)
      |> sign_tx(["ed25519_sk1tmxtkw3ek64zyg9gtn3qkk355hfs9jnfjy33zwp87s8qkdmznd0qvukr43"])
      |> submit_tx()

    IO.puts("Transaction Submitted with TxId: #{tx_id}")
  end
end

Sutra.Examples.Advance.AlwaysSucceed.run()
