defmodule Sutra.Cardano.Types.Output do
  @moduledoc """
    Cardano Output
  """
  alias Sutra.Cardano.Types.Datum
  alias Sutra.Cardano.Address

  use Sutra.Data

  defdata do
    data(:address, Address,
      encode_with: &Address.to_plutus/1,
      decode_with: &Address.from_plutus/1
    )

    data(:value, :string)
    data(:datum, Datum)
    data(:reference_script, ~OPTION(:string))
  end
end
