defmodule Sutra.Cardano.Common.PoolRelay do
  @moduledoc """
    This module defines the relay information for a pool.

    It can be of three types:
    1. single host address,
    2. single host name
    3. multiple host names.

    ## CDDL
    https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/conway/impl/cddl-files/conway.cddl#L347
    ```
      relay = [single_host_addr // single_host_name // multi_host_name]

    ```

  """

  use TypedStruct
  alias __MODULE__.{SingleHostAddr, SingleHostName, MultiHostName}

  @type t() :: SingleHostAddr.t() | SingleHostName.t() | MultiHostName.t()

  typedstruct(module: SingleHostAddr) do
    @moduledoc """
      Single Host Address Relay

      ## CDDL
      ```
      single_host_addr = (0, port / nil, ipv4 / nil, ipv6 / nil)
      ```
    """
    field(:port, :integer)
    field(:ipv4, :string)
    field(:ipv6, :string)
  end

  typedstruct(module: SingleHostName) do
    @moduledoc """
      Single Host Name Relay

      ## CDDL
      ```
      single_host_name = (1, port / nil, dns_name)
      ```
    """
    field(:port, :integer)
    field(:dns_name, :string)
  end

  typedstruct(module: MultiHostName) do
    @moduledoc """
      Multiple Host Name Relay

      ## CDDL
      ```
      multi_host_name = (2, dns_name)
      ```
    """

    field(:dns_name, :string)
  end

  @doc """
    Decode the relay information from the CBOR data.

    ## Examples

      iex> decode([0, "8080", "192.168.1.1", "2001:0db8:85a3:0000:0000:8a2e:0370:7334"])
      %SingleHostAddr{}

      iex> decode([1, "8080", "example.com"])
      %SingleHostName{}

      iex> decode([2, "example.com"])
      %MultiHostName{}

  """
  def decode([0, port, ipv4, ipv6]) do
    %SingleHostAddr{port: port, ipv4: ipv4, ipv6: ipv6}
  end

  def decode([1, port, dns_name]) do
    %SingleHostName{port: port, dns_name: dns_name}
  end

  def decode([2, dns_name]) do
    %MultiHostName{dns_name: dns_name}
  end

  @doc """
    Encode the relay information to the CBOR data.

    ## Examples

      iex> encode(%SingleHostAddr{})
      [0, port, ipv4, ipv6]

      iex> encode(%SingleHostName{})
      [1, port, dns_name]

      iex> encode(%MultiHostName{})
      [2, dns_name]

  """
  def encode(%SingleHostAddr{port: port, ipv4: ipv4, ipv6: ipv6}) do
    [0, port, ipv4, ipv6]
  end

  def encode(%SingleHostName{port: port, dns_name: dns_name}) do
    [1, port, dns_name]
  end

  def encode(%MultiHostName{dns_name: dns_name}) do
    [2, dns_name]
  end
end
