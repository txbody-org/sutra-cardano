defmodule Sutra.Cardano.Transaction.AccountBalanceIntervalTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Sutra.Cardano.Address.Credential
  alias Sutra.Cardano.Transaction.AccountBalanceInterval

  @key_hash "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
  @script_hash "a687dcc24e00dd3caafbeb5e68f97ca8ef269cb6fe971345eb951756"

  describe "single interval round trip" do
    test "both bounds set" do
      interval = %AccountBalanceInterval{
        inclusive_lower_bound: 1_000_000,
        exclusive_upper_bound: 5_000_000
      }

      assert interval |> AccountBalanceInterval.to_cbor() |> AccountBalanceInterval.decode!() ==
               interval
    end

    test "upper bound unbounded (nil)" do
      interval = %AccountBalanceInterval{
        inclusive_lower_bound: 1_000_000,
        exclusive_upper_bound: nil
      }

      assert interval |> AccountBalanceInterval.to_cbor() |> AccountBalanceInterval.decode!() ==
               interval
    end

    test "lower bound unbounded (nil)" do
      interval = %AccountBalanceInterval{
        inclusive_lower_bound: nil,
        exclusive_upper_bound: 5_000_000
      }

      assert interval |> AccountBalanceInterval.to_cbor() |> AccountBalanceInterval.decode!() ==
               interval
    end
  end

  describe "account_balance_intervals map round trip" do
    test "encode_all/1 and decode_all/1 round trip for vkey and script credentials" do
      intervals = %{
        %Credential{credential_type: :vkey, hash: @key_hash} => %AccountBalanceInterval{
          inclusive_lower_bound: 0,
          exclusive_upper_bound: 10_000_000
        },
        %Credential{credential_type: :script, hash: @script_hash} => %AccountBalanceInterval{
          inclusive_lower_bound: 2_000_000,
          exclusive_upper_bound: nil
        }
      }

      assert intervals
             |> AccountBalanceInterval.encode_all()
             |> AccountBalanceInterval.decode_all() == intervals
    end

    test "decode_all/1 returns nil when not a map" do
      assert AccountBalanceInterval.decode_all(nil) == nil
    end
  end
end
