defmodule Sutra.Cardano.Transaction.TxBuilder.TxConfig do
  @moduledoc """
    Transaction Config
  """

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction.TxBuilder.Error.ConfigError
  alias Sutra.ProtocolParams
  alias Sutra.Provider
  alias Sutra.SlotConfig
  alias Sutra.Utils

  import Sutra.Utils, only: [maybe: 2]

  defstruct protocol_params: nil,
            wallet_address: nil,
            change_address: nil,
            change_datum: nil,
            provider: nil,
            slot_config: nil,
            evaluate_provider_uplc: false,
            debug: false

  def __override_cfg(%__MODULE__{} = cfg, _, nil), do: cfg

  def __override_cfg(%__MODULE__{} = cfg, key, value), do: Map.put_new(cfg, key, value)

  def __set_cfg(%__MODULE__{} = cfg, key, value), do: Map.put(cfg, key, value)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def __setup(%__MODULE__{} = cfg, opts \\ []) do
    Enum.reduce(opts, cfg, fn curr_opt, %__MODULE__{} = acc ->
      case curr_opt do
        {_, nil} ->
          acc

        {_, []} ->
          acc

        {:slot_config, %SlotConfig{} = slot_cfg} ->
          %__MODULE__{acc | slot_config: slot_cfg}

        {:protocol_params, %ProtocolParams{} = v} ->
          %__MODULE__{acc | protocol_params: v}

        {:provider, v} ->
          %__MODULE__{acc | provider: v}

        {:wallet_address, addresses} when is_list(addresses) ->
          %__MODULE__{acc | wallet_address: Enum.map(addresses, &parse_address/1)}

        {:wallet_address, address} ->
          %__MODULE__{acc | wallet_address: [parse_address(address)]}

        {:change_address, %Address{} = address} ->
          %__MODULE__{acc | change_address: address}

        {:change_address, address} when is_binary(address) ->
          %__MODULE__{acc | change_address: Address.from_bech32(address)}

        {:evaluate_provider_uplc, v} when is_boolean(v) ->
          %__MODULE__{acc | evaluate_provider_uplc: v}

        _ ->
          acc
      end
    end)
  end

  defp parse_address(%Address{} = addr), do: addr

  defp parse_address(bech_32_addr) when is_binary(bech_32_addr),
    do: Address.from_bech32(bech_32_addr)

  @doc """
    Setup Wallet Utxos, protocol_params if not setup manually
  """

  def __init(%__MODULE__{provider: nil} = cfg) do
    case Provider.get_fetcher() do
      {:ok, provider} ->
        __init(%__MODULE__{cfg | provider: provider})

      _ ->
        cfg
    end
  end

  def __init(%__MODULE__{} = cfg) do
    Enum.reduce(Map.from_struct(cfg), cfg, fn cfg_field, %__MODULE__{} = acc ->
      case cfg_field do
        {:wallet_address, wallet_addrs} when is_list(wallet_addrs) ->
          %__MODULE__{
            acc
            | change_address: maybe(cfg.change_address, Utils.safe_head(wallet_addrs))
          }

        {:change_address, %Address{} = change_address} ->
          %__MODULE__{acc | change_address: change_address}

        {:provider, provider} when not is_nil(provider) ->
          %__MODULE__{
            acc
            | protocol_params: maybe(cfg.protocol_params, fn -> provider.protocol_params() end),
              slot_config: maybe(cfg.slot_config, provider.slot_config())
          }

        _ ->
          acc
      end
    end)
  end

  def validate(%__MODULE__{} = cfg) do
    cond do
      is_nil(cfg.provider) ->
        {:error, %ConfigError{reason: "Provider Not Set"}}

      not Utils.instance_of?(cfg.change_address, Address) ->
        {:error, %ConfigError{reason: "Change Address not Available"}}

      not Utils.instance_of?(cfg.protocol_params, ProtocolParams) ->
        {:error, %ConfigError{reason: "Protocol params Missing"}}

      not Utils.instance_of?(cfg.slot_config, SlotConfig) ->
        {:error, %ConfigError{reason: "Slot Config missing"}}

      true ->
        {:ok, cfg}
    end
  end
end
