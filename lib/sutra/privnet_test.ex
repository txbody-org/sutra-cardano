defmodule Sutra.PrivnetTest do
  @moduledoc """
  PrivNet Test  Module Library
  """
  alias Sutra.Cardano.Asset
  alias Sutra.Crypto.Key
  alias Sutra.Provider.YaciProvider
  alias Sutra.Utils

  use ExUnit.CaseTemplate

  @default_mnemonic "test test test test test test test test test test test test test test test test test test test test test test test sauce"

  @default_root_key Key.root_key_from_mnemonic(@default_mnemonic)
                    |> Utils.when_ok(&Utils.identity/1)

  using do
    quote do
      use ExUnit.Case, async: false

      import Sutra.PrivnetTest
    end
  end

  def with_default_wallet(user_indx, func) when user_indx >= 0 and user_indx <= 20 do
    {:ok, signing_key} = Key.derive_child(@default_root_key, 0, user_indx)

    {:ok, address} = Key.address(signing_key, :preprod)

    if YaciProvider.balance_of(address) == Asset.zero() do
      load_ada(address, [10_000, 5])
    end

    func.(%{signing_key: signing_key, root_key: @default_root_key, address: address})
  end

  def with_default_wallet(user_indx, _),
    do:
      raise("""
        only Support 20 default wallet user Index. supplied: #{user_indx}
      """)

  def load_ada(address, amt) when is_integer(amt), do: YaciProvider.topup(address, amt)

  def load_ada(address, amounts) when is_list(amounts) do
    Enum.map(amounts, &load_ada(address, &1))
  end

  def with_new_wallet(func) do
    {:ok, root_key} = Key.root_key_from_mnemonic(Mnemonic.generate())
    {:ok, child_key} = Key.derive_child(root_key, 0, 0)
    {:ok, address} = Key.address(child_key, :preprod)

    load_ada(address, [100, 5])

    func.(%{signing_key: child_key, root_key: root_key, address: address})
  end

  def random_address do
    {:ok, root_key} = Key.root_key_from_mnemonic(Mnemonic.generate())

    {:ok, address} = Key.address(root_key, :preprod)
    address
  end

  def await_tx(tx_id), do: await_tx(tx_id, 3)

  def await_tx(_, retry) when retry < 0, do: nil

  def await_tx(tx_id, retry) do
    case YaciProvider.get_tx_info(tx_id) do
      resp when is_map(resp) ->
        resp

      _ ->
        Process.sleep(1000)
        await_tx(tx_id, retry - 1)
    end
  end

  setup _tags do
    if Application.get_env(:sutra, :provider) != YaciProvider,
      do: set_yaci_provider_env()

    if not YaciProvider.running?(),
      do:
        raise("""
          Yaci Provider is not running. Start Yaci Provider before running Test
        """)

    :ok
  end

  defp set_yaci_provider_env do
    Application.put_env(:sutra, :provider, YaciProvider)

    Application.put_env(
      :sutra,
      :yaci_general_api_url,
      System.get_env("YACI_GENERAL_API_URL", "http://localhost:8080")
    )

    Application.put_env(
      :sutra,
      :yaci_admin_api_url,
      System.get_env("YACI_ADMIN_API_URL", "http://localhost:10000")
    )
  end
end
