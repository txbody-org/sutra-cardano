defmodule Sutra.Cardano.Transaction do
  @moduledoc ~S"""
    Cardano Transaction
  """

  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction.Witness
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Data.Cbor
  alias Sutra.Data.Plutus.PList

  use Sutra.Data

  use TypedStruct

  typedstruct do
    field(:tx_body, TxBody.t())
    field(:witnesses, [Witness.t()])
    field(:is_valid, boolean())
    field(:metadata, any())
  end

  def from_hex(cbor) when is_binary(cbor) do
    case Sutra.Data.decode(cbor) do
      {:ok, data} -> from_cbor(data)
      {:error, _} -> {:error, :invalid_cbor}
    end
  end

  # Conway era transaction
  def from_cbor(%PList{value: [tx_body, witness, is_valid, metadata]})
      when is_boolean(is_valid) do
    witness =
      Enum.reduce(Cbor.extract_value!(witness), [], fn w, acc ->
        acc ++ Witness.decode(w)
      end)

    %__MODULE__{
      tx_body: TxBody.decode(tx_body),
      witnesses: witness,
      is_valid: is_valid,
      metadata: metadata
    }
  end

  def from_cbor(%PList{value: values}) do
    IO.inspect("Other Era TX ...")
    IO.inspect(values)
  end
end
