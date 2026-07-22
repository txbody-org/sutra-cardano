defmodule Sutra.Cardano.Transaction.AccountBalanceInterval do
  @moduledoc """
    Cardano Account Balance Interval (Dijkstra)

    ## CDDL

    account_balance_intervals = {+ credential => account_balance_interval}

    account_balance_interval =
      [  inclusive_lower_bound : coin, exclusive_upper_bound : coin/ nil
      // inclusive_lower_bound : coin/ nil, exclusive_upper_bound : coin
      ]
  """

  alias Sutra.Cardano.Address

  use TypedStruct

  typedstruct do
    field(:inclusive_lower_bound, integer())
    field(:exclusive_upper_bound, integer())
  end

  def decode!([lower_bound, upper_bound]) do
    %__MODULE__{inclusive_lower_bound: lower_bound, exclusive_upper_bound: upper_bound}
  end

  def to_cbor(%__MODULE__{inclusive_lower_bound: lower_bound, exclusive_upper_bound: upper_bound}) do
    [lower_bound, upper_bound]
  end

  @doc """
    Decode `account_balance_intervals = {+ credential => account_balance_interval}`
  """
  def decode_all(account_balance_intervals) when is_map(account_balance_intervals) do
    for {credential, interval} <- account_balance_intervals, into: %{} do
      {Address.credential_from_cbor(credential), decode!(interval)}
    end
  end

  def decode_all(_), do: nil

  def encode_all(account_balance_intervals) when is_map(account_balance_intervals) do
    for {credential, interval} <- account_balance_intervals, into: %{} do
      {Address.credential_to_cbor(credential), to_cbor(interval)}
    end
  end
end
