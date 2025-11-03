defmodule Sutra.Test.Support.BlueprintSupport do
  @moduledoc false

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript

  @simple_blueprint_url "./blueprint.json"

  @always_pass_path "./always_true.plutus"

  def get_simple_script(validator_name) do
    File.read!(@simple_blueprint_url)
    |> :elixir_json.decode()
    |> Map.get("validators", [])
    |> Enum.find(fn v -> v["title"] == validator_name end)
    |> Map.get("compiledCode")
  end

  def always_true_script(id \\ :rand.bytes(20)) do
    File.read!(@always_pass_path)
    |> String.trim()
    |> Script.apply_params([Base.encode16(id)])
    |> Script.new(:plutus_v3)
  end

  def always_true_native_script(%Address{payment_credential: %Credential{hash: pubkey_hash}}) do
    script_json = %{
      "type" => "all",
      "scripts" => [
        %{
          "type" => "sig",
          "keyHash" => pubkey_hash
        }
      ]
    }

    NativeScript.from_json(script_json)
  end
end
