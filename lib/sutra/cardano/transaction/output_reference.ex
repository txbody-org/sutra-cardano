defmodule Sutra.Cardano.Transaction.OutputReference do
  @moduledoc """
    Cardano Transaction Output Reference
  """

  alias Sutra.Data.Cbor

  use Sutra.Data

  @type t() :: %__MODULE__{
          transaction_id: String.t(),
          output_index: integer()
        }

  defdata do
    data(:transaction_id, :string)
    data(:output_index, :integer)
  end

  def to_cbor(%__MODULE__{} = out_ref) do
    [Cbor.as_byte(out_ref.transaction_id), out_ref.output_index]
  end

  def from_cbor([tx_id, output_index]) do
    %__MODULE__{
      transaction_id: Cbor.extract_value!(tx_id),
      output_index: output_index
    }
  end
end
