defmodule Sutra.Provider.Kupogmios.ClientTest do
  use ExUnit.Case, async: false
  alias Sutra.Provider.Kupogmios.Client

  describe "new/1" do
    test "validates kupo_url and ogmios_url from options" do
      client = Client.new(kupo_url: "http://kupo", ogmios_url: "http://ogmios")
      assert client.kupo.options.base_url == "http://kupo"
      assert client.ogmios.options.base_url == "http://ogmios"
    end

    test "configures clients correctly" do
      client = Client.new(kupo_url: "http://kupo", ogmios_url: "http://ogmios")
      assert %Req.Request{} = client.kupo
      assert %Req.Request{} = client.ogmios
    end

    test "raises error when kupo_url is missing" do
      # Ensure env is empty
      old_env = Application.get_env(:sutra, :kupogmios)
      Application.put_env(:sutra, :kupogmios, nil)

      on_exit(fn ->
        if old_env,
          do: Application.put_env(:sutra, :kupogmios, old_env),
          else: Application.delete_env(:sutra, :kupogmios)
      end)

      assert_raise ArgumentError, ~r/kupo_url is required/, fn ->
        Client.new(ogmios_url: "http://ogmios")
      end
    end

    test "raises error when ogmios_url is missing" do
      old_env = Application.get_env(:sutra, :kupogmios)
      Application.put_env(:sutra, :kupogmios, nil)

      on_exit(fn ->
        if old_env,
          do: Application.put_env(:sutra, :kupogmios, old_env),
          else: Application.delete_env(:sutra, :kupogmios)
      end)

      assert_raise ArgumentError, ~r/ogmios_url is required/, fn ->
        Client.new(kupo_url: "http://kupo")
      end
    end

    test "raises error when url is empty string" do
      assert_raise ArgumentError, ~r/kupo_url is required/, fn ->
        Client.new(kupo_url: "", ogmios_url: "http://ogmios")
      end

      assert_raise ArgumentError, ~r/ogmios_url is required/, fn ->
        Client.new(kupo_url: "http://kupo", ogmios_url: "")
      end
    end

    test "uses configured defaults if options are missing" do
      Application.put_env(:sutra, :kupogmios,
        kupo_url: "http://env-kupo",
        ogmios_url: "http://env-ogmios"
      )

      on_exit(fn -> Application.delete_env(:sutra, :kupogmios) end)

      client = Client.new()
      assert client.kupo.options.base_url == "http://env-kupo"
      assert client.ogmios.options.base_url == "http://env-ogmios"
    end

    test "options override configuration" do
      Application.put_env(:sutra, :kupogmios,
        kupo_url: "http://env-kupo",
        ogmios_url: "http://env-ogmios"
      )

      on_exit(fn -> Application.delete_env(:sutra, :kupogmios) end)

      client = Client.new(kupo_url: "http://opt-kupo", ogmios_url: "http://opt-ogmios")
      assert client.kupo.options.base_url == "http://opt-kupo"
      assert client.ogmios.options.base_url == "http://opt-ogmios"
    end

    test "ignores explicitly nil options and falls back to config" do
      Application.put_env(:sutra, :kupogmios,
        kupo_url: "http://env-kupo",
        ogmios_url: "http://env-ogmios"
      )

      on_exit(fn -> Application.delete_env(:sutra, :kupogmios) end)

      client = Client.new(kupo_url: nil, ogmios_url: nil)
      assert client.kupo.options.base_url == "http://env-kupo"
      assert client.ogmios.options.base_url == "http://env-ogmios"
    end
  end
end
