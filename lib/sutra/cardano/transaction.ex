defmodule Sutra.Cardano.Transaction do
  @moduledoc ~S"""
    Cardano Transaction
  """

  alias __MODULE__.Output
  alias Sutra.Blake2b
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Cardano.Transaction.TxBody
  alias Sutra.Cardano.Transaction.Witness
  alias Sutra.Data.Cbor

  use Sutra.Data

  use TypedStruct

  use Sutra.Data

  @type input() :: %Input{
          output_reference: OutputReference.t(),
          output: Output.t()
        }

  defmodule Input do
    @moduledoc """
      Transaction Input
    """
    defdata do
      data(:output_reference, OutputReference)
      data(:output, Output)
    end

    def sort_inputs(inputs) when is_list(inputs) do
      Enum.sort_by(inputs, & &1.output_reference, {:asc, OutputReference})
    end
  end

  typedstruct do
    field(:tx_body, TxBody.t())
    field(:witnesses, Witness.t())
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
  def from_hex(cbor_hex) when is_binary(cbor_hex) do
    decoded_cbor =
      cbor_hex
      |> Base.decode16!(case: :mixed)
      |> CBOR.decode()

    case decoded_cbor do
      {:ok, cbor, _} -> from_cbor(cbor)
      {:error, err} -> {:error, err}
    end
  end

  @doc """
    Generate transaction from cbor

    iex> from_cbor([valid_tx_body, valid_witness_cbor, true, metadata])
    %Sutra.Cardano.Transaction{}
  """
  def from_cbor([tx_body, witness_cbor, is_valid, metadata])
      when is_boolean(is_valid) do
    %__MODULE__{
      tx_body: TxBody.decode(tx_body),
      witnesses: Witness.from_cbor(Cbor.extract_value!(witness_cbor)),
      is_valid: is_valid,
      metadata: metadata
    }
  end

  def from_cbor(_) do
    raise """
      Only Conway era transaction supported. Todo: support other eras.
    """
  end

  @doc """
    Convert transaction to hex encoded cbor

    iex> to_hex(%Sutra.Cardano.Transaction{})
    "some-valid-hex-encoded-cbor"
  """
  def to_cbor(%__MODULE__{} = tx) do
    tx_body_cbor = TxBody.to_cbor(tx.tx_body)

    [tx_body_cbor, Witness.to_cbor(tx.witnesses), tx.is_valid, tx.metadata]
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
