defmodule Sutra.Cardano.Data.DataBehavior do
  @moduledoc """
    Data Behavior
  """
  @callback from_plutus(binary(), any()) :: {:ok, any()} | {:error, any()}
  @callback to_plutus(any()) :: binary()
end
