defmodule Sutra.Test.Support.BlueprintSupport do
  @moduledoc false

  @simple_blueprint_url "./blueprint.json"

  def get_simple_script(validator_name) do
    File.read!(@simple_blueprint_url)
    |> :elixir_json.decode()
    |> Map.get("validators", [])
    |> Enum.find(fn v -> v["title"] == validator_name end)
    |> Map.get("compiledCode")
  end
end
