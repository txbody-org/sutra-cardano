defmodule Sutra.SlotConfig do
  @moduledoc """
   Slot Configuration 
  """

  @enforce_keys [:zero_time, :zero_slot, :slot_length]
  defstruct [:zero_time, :zero_slot, :slot_length]

  @mainnet_config %{
    zero_time: 1_596_059_091_000,
    zero_slot: 4_492_800,
    slot_length: 1000
  }

  @preprod_config %{
    zero_time: 1_654_041_600_000 + 1_728_000_000,
    zero_slot: 86_400,
    slot_length: 1000
  }

  @preview_config %{
    zero_time: 1_666_656_000_000,
    zero_slot: 0,
    slot_length: 1000
  }

  def fetch_slot_config(network) do
    case network do
      :mainnet -> struct(__MODULE__, @mainnet_config)
      :preprod -> struct(__MODULE__, @preprod_config)
      :preview -> struct(__MODULE__, @preview_config)
      _ -> nil
    end
  end

  def slot_to_begin_unix_time(slot, %__MODULE__{
        zero_time: zero_time,
        zero_slot: zero_slot,
        slot_length: slot_length
      })
      when is_integer(slot) do
    zero_time + (slot - zero_slot) * slot_length
  end

  def unix_time_to_slot(unix_time, %__MODULE__{
        zero_time: zero_time,
        zero_slot: zero_slot,
        slot_length: slot_length
      })
      when is_integer(unix_time) do
    time_passed = unix_time - zero_time
    slot_passed = floor(time_passed / slot_length)
    slot_passed + zero_slot
  end
end
