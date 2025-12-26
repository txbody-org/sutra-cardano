# Setup Provider
Code.eval_file("examples/setup_provider.exs")

# Check required Env Vars
address = System.get_env("TEST_ADDRESS")
signing_key = System.get_env("TEST_SIGNING_KEY")

if is_nil(address) or is_nil(signing_key) do
  IO.puts("Error: TEST_ADDRESS and TEST_SIGNING_KEY must be set.")
  System.halt(1)
end

defmodule Sutra.Examples.Advance.SimpleGuessSpend do
  @moduledoc false

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Script
  alias Sutra.Provider

  def run(wallet_address, sig) do
    script_code =
      File.read!("./blueprint.json")
      |> :elixir_json.decode()
      |> Map.get("validators", [])
      |> Enum.find(fn v -> v["title"] == "simple.simple.spend" end)
      |> Map.get("compiledCode")
      |> Script.apply_params([Base.encode16("spend-params")])

    script = %Script{script_type: :plutus_v3, data: script_code}

    # Derive address using the provider's configured network if possible, or fallback to :testnet (which is usually preprod/preview compatible address-wise for scrips?)
    # Ideally should get network from config, but for now :testnet covers both.
    # Actually, let's try to get it from provider logic or default to :preprod
    network = Application.get_env(:sutra, :network, :preprod)
    script_address = Address.from_script(script, network)

    IO.puts("Placing Utxo to Script with Guess: 42")

    place_tx_id =
      Sutra.new_tx()
      |> Sutra.add_output(script_address, %{}, {:datum_hash, 42})
      |> Sutra.build_tx!(wallet_address: wallet_address)
      |> Sutra.sign_tx([sig])
      |> Sutra.submit_tx()

    IO.puts("Place Tx Submitted, Txid: #{place_tx_id}")

    IO.puts("Confirming Tx ....")

    {:ok, provider} = Provider.get_fetcher()

    case Provider.await_tx(place_tx_id) do
      :ok ->
        :ok

      {:error, :timeout} ->
        IO.puts("Error: Timed out waiting for Tx #{place_tx_id}")
        System.halt(1)
    end

    input_utxos = provider.utxos_at_tx_refs(["#{place_tx_id}#0"])

    spend_tx_id =
      Sutra.new_tx()
      |> Sutra.add_input(input_utxos, witness: script, redeemer: 42)
      |> Sutra.build_tx!(wallet_address: wallet_address)
      |> Sutra.sign_tx([sig])
      |> Sutra.submit_tx()

    case spend_tx_id do
      %{} = error ->
        IO.inspect(error, label: "Spend Submission Failed")
        System.halt(1)

      hash when is_binary(hash) ->
        IO.puts("Spending UTxO from Script with Guess: 42 #{hash}")

      _ ->
        IO.inspect(spend_tx_id, label: "Unknown Response from Submit")
        System.halt(1)
    end
  end

  # end of module
end

Sutra.Examples.Advance.SimpleGuessSpend.run(address, signing_key)
