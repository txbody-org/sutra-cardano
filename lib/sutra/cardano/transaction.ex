defmodule Sutra.Cardano.Transaction do
  @moduledoc ~S"""
    Cardano Transaction
  """

  alias Sutra.Blake2b
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction.Witness
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

  @doc """
    Generate transaction from hex encoded cbor

    iex> from_hex("valid-hex-transaction")
    {:ok, %Sutra.Cardano.Transaction{}}

    iex> from_hex("some-invalid-hex-transaction")
    {:error, :invalid_cbor}
    
  """
  def from_hex(cbor) when is_binary(cbor) do
    case Sutra.Data.decode(cbor) do
      {:ok, data} -> from_cbor(data)
      {:error, _} -> {:error, :invalid_cbor}
    end
  end

  @doc """
    Generate transaction from cbor

    iex> from_cbor(%PList{value: [valid_tx_body, valid_witness_cbor, true, metadata]})
    %Sutra.Cardano.Transaction{}
  """
  @spec from_cbor(CBOR.Tag.t()) :: __MODULE__.t()
  def from_cbor(%PList{value: [tx_body, witness_cbor, is_valid, metadata]})
      when is_boolean(is_valid) do
    witness =
      Enum.reduce(Cbor.extract_value!(witness_cbor), [], fn w, acc ->
        acc ++ Witness.decode(w)
      end)

    %__MODULE__{
      tx_body: TxBody.decode(tx_body),
      witnesses: witness,
      is_valid: is_valid,
      metadata: metadata
    }
  end

  def from_cbor(%PList{value: _values}) do
    raise """
      Only Conway era transaction supported. Todo: support other eras.
    """
  end

  @doc """
    Convert transaction to hex encoded cbor

    iex> to_hex(%Sutra.Cardano.Transaction{})
    "some-valid-hex-encoded-cbor"
  """
  @spec to_cbor(__MODULE__.t()) :: Cbor.t()
  def to_cbor(%__MODULE__{} = tx) do
    tx_body_cbor = TxBody.to_cbor(tx.tx_body)

    %PList{value: [tx_body_cbor, Witness.to_cbor(tx.witnesses), tx.is_valid, tx.metadata]}
  end

  @doc """
    Get transaction id

    iex> tx_id(%Sutra.Cardano.Transaction{})
    "88350824a9557e16a8f18b9b3cc4ab7cc0c282c178132083babde3cdb33393ee"

  """
  @spec tx_id(__MODULE__.t()) :: Blake2b.blake2b_256()
  def tx_id(%__MODULE__{} = tx) do
    tx.tx_body
    |> TxBody.to_cbor()
    |> CBOR.encode()
    |> Blake2b.blake2b_256()
  end
end
