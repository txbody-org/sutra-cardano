defmodule Sutra.Cardano.Common.PoolRelay do
  @moduledoc """
    Pool Relay Information
  """

  use TypedStruct

  typedstruct(module: SingleHostAddr) do
    field(:port, :integer)
    field(:ipv4, :string)
    field(:ipv6, :string)
  end

  typedstruct(module: SingleHostName) do
    field(:port, :integer)
    field(:dns_name, :string)
  end

  typedstruct(module: MultiHostName) do
    field(:dns_name, :string)
  end

  def decode([0, port, ipv4, ipv6]) do
    %SingleHostAddr{port: port, ipv4: ipv4, ipv6: ipv6}
  end

  def decode([1, port, dns_name]) do
    %SingleHostName{port: port, dns_name: dns_name}
  end

  def decode([2, dns_name]) do
    %MultiHostName{dns_name: dns_name}
  end
end

