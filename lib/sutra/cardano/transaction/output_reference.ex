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

  def compare(%__MODULE__{} = ref1, %__MODULE__{} = ref2)
      when is_binary(ref1.transaction_id) and ref1.transaction_id == ref2.transaction_id do
    if ref1.output_index > ref2.output_index, do: :gt, else: :lt
  end

  def compare(%__MODULE__{} = ref1, %__MODULE__{} = ref2)
      when is_binary(ref1.transaction_id) and is_binary(ref2.transaction_id) do
    if ref1.transaction_id > ref2.transaction_id, do: :gt, else: :lt
  end
end
