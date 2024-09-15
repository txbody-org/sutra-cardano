defmodule Sutra.Cardano.Transaction.Datum do
  @moduledoc """
    Cardano Transaction Datum
  """

  use Sutra.Data

  defenum(no_datum: :null, datum_hash: :string, inline_datum: :string)
end
