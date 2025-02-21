defmodule Sutra.Cardano.Transaction.TxBuilder.TxConfig do
  @moduledoc """
    Transaction Config
  """
  alias Sutra.Cardano.Address
  alias Sutra.ProtocolParams

  import Sutra.Utils, only: [maybe: 2]

  defstruct [
    :protocol_params,
    :wallet_address,
    :change_address,
    :change_datum,
    :wallet_utxos,
    :provider,
    :slot_config
  ]

  def __override_cfg(%__MODULE__{} = cfg, _, nil), do: cfg

  def __override_cfg(%__MODULE__{} = cfg, key, value) do
    case Map.get(cfg, key) do
      nil ->
        Map.put(cfg, key, value)

      _ ->
        cfg
    end
  end

  def __set_cfg(%__MODULE__{} = cfg, key, value), do: Map.put(cfg, key, value)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def __setup(%__MODULE__{} = cfg, opts \\ []) do
    Enum.reduce(opts, cfg, fn curr_opt, acc ->
      case curr_opt do
        {_, nil} ->
          acc

        {_, []} ->
          acc

        {:protocol_params, %ProtocolParams{} = v} ->
          %__MODULE__{acc | protocol_params: v}

        {:wallet_utxos, utxos} ->
          %__MODULE__{acc | wallet_utxos: utxos}

        {:provider, v} when is_map(v) ->
          %__MODULE__{acc | provider: v}

        {:wallet_address, %Address{} = address} ->
          %__MODULE__{acc | wallet_address: address}

        {:wallet_address, address} when is_binary(address) ->
          %__MODULE__{acc | wallet_address: Address.from_bech32(address)}

        {:change_address, %Address{} = address} ->
          %__MODULE__{acc | change_address: address}

        {:change_address, address} when is_binary(address) ->
          %__MODULE__{acc | change_address: Address.from_bech32(address)}

        _ ->
          acc
      end
    end)
  end

  @doc """
    Setup Wallet Utxos, protocol_params if not setup manually
  """

  # TODO: use is_provider() guard, fetch def protocl params
  def __init(%__MODULE__{provider: nil} = cfg), do: cfg

  def __init(%__MODULE__{wallet_address: nil, protocol_params: nil} = cfg) do
    %__MODULE__{protocol_params: cfg.provider.protocol_params()}
  end

  def __init(%__MODULE__{provider: provider} = cfg) do
    Enum.reduce(Map.from_struct(cfg), cfg, fn cfg_field, %__MODULE__{} = acc ->
      case cfg_field do
        {:wallet_address, %Address{} = wallet_addr} ->
          %__MODULE__{
            acc
            | wallet_utxos:
                maybe(cfg.wallet_utxos, fn ->
                  provider.utxos_at([wallet_addr])
                end),
              change_address: maybe(cfg.change_address, wallet_addr)
          }

        {:change_address, %Address{} = change_address} ->
          %__MODULE__{acc | change_address: change_address}

        {:provider, provider} when not is_nil(provider) ->
          %__MODULE__{
            acc
            | protocol_params: maybe(cfg.protocol_params, fn -> provider.protocol_params() end),
              slot_config: provider.slot_config()
          }

        _ ->
          acc
      end
    end)
  end
end
