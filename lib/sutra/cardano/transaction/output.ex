defmodule Sutra.Cardano.Transaction.Output do
  @moduledoc """
    Cardano Transaction Output
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Transaction.Datum

  use Sutra.Data

  defdata(name: OutputReference) do
    data(:transaction_id, :string)
    data(:output_index, :integer)
  end

  defdata do
    data(:address, Address)
    data(:value, Asset)
    data(:datum, Datum)
    data(:reference_script, ~OPTION(:string))
  end
end
