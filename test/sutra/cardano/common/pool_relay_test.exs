defmodule Sutra.Cardano.Common.PoolRelayTest do
  use ExUnit.Case

  alias Sutra.Cardano.Common.PoolRelay
  alias Sutra.Cardano.Common.PoolRelay.{SingleHostAddr, SingleHostName, MultiHostName}

  describe "decode/1" do
    test "decodes single_host_addr" do
      data = [0, 8080, "192.168.1.1", "2001:0db8:85a3:0000:0000:8a2e:0370:7334"]
      assert %SingleHostAddr{port: 8080, ipv4: "192.168.1.1"} = PoolRelay.decode(data)
    end

    test "decodes single_host_name" do
      data = [1, 8080, "example.com"]
      assert %SingleHostName{port: 8080, dns_name: "example.com"} = PoolRelay.decode(data)
    end

    test "decodes multi_host_name" do
      data = [2, "example.com"]
      assert %MultiHostName{dns_name: "example.com"} = PoolRelay.decode(data)
    end
  end

  describe "encode/1" do
    test "encodes single_host_addr" do
      relay = %SingleHostAddr{port: 8080, ipv4: "192.168.1.1", ipv6: "2001:db8::1"}
      assert [0, 8080, "192.168.1.1", "2001:db8::1"] == PoolRelay.encode(relay)
    end

    test "encodes single_host_name" do
      relay = %SingleHostName{port: 8080, dns_name: "example.com"}
      assert [1, 8080, "example.com"] == PoolRelay.encode(relay)
    end

    test "encodes multi_host_name" do
      relay = %MultiHostName{dns_name: "example.com"}
      assert [2, "example.com"] == PoolRelay.encode(relay)
    end
  end
end
