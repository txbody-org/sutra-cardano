defmodule Sutra.Cardano.Types.Datum do
  @moduledoc """
    Cardano Datum
  """

  use Sutra.Data

  defenum(no_datum: :null, datum_hash: :string, inline_datum: :string)
end
