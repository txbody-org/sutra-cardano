defmodule Sutra.DataTest do
  @moduledoc false

  use ExUnit.Case, async: true

  use Sutra.Data

  alias Sutra.Cardano.Transaction.Datum
  alias Sutra.Data.Cbor

  defdata name: SampleData do
    data(:val, :string)
  end

  defdata do
    data(:another, :string)
  end

  test "def data can be directly encoded" do
    assert Cbor.encode_hex(%__MODULE__.SampleData{val: "some-val"}) ==
             "D8799F48736F6D652D76616CFF"

    assert Cbor.encode_hex(%__MODULE__{another: "another-val"}) ==
             "D8799F4B616E6F746865722D76616CFF"

    assert Cbor.encode_hex(%Datum{kind: :no_datum}) == "D87980"
  end
end
