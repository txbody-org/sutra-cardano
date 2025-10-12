defmodule Sutra.Test.Support.BuilderSupport do
  @moduledoc false

  alias Sutra.Blake2b
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Script
  alias Sutra.Cardano.Script.NativeScript
  alias Sutra.Cardano.Transaction.Input
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.OutputReference
  alias Sutra.Common.ExecutionUnitPrice
  alias Sutra.ProtocolParams

  @sample_addr "addr1gx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer5pnz75xxcrzqf96k"
  @script_all %{
    "type" => "all",
    "scripts" => [
      %{
        "type" => "sig",
        "keyHash" => "e09d36c79dec9bd1b3d9e152247701cd0bb860b5ebfd1de8abb6735a"
      },
      %{
        "type" => "sig",
        "keyHash" => "a687dcc24e00dd3caafbeb5e68f97ca8ef269cb6fe971345eb951756"
      },
      %{
        "type" => "sig",
        "keyHash" => "0bd1d702b2e6188fe0857a6dc7ffb0675229bab58c86638ffa87ed6d"
      }
    ]
  }

  def input(asset, ref_script \\ nil) do
    %Input{
      output_reference: %OutputReference{
        transaction_id: Blake2b.blake2b_256("#{:rand.uniform(10000)}"),
        output_index: :rand.uniform(50)
      },
      output: Output.new(Address.from_bech32(@sample_addr), asset, reference_script: ref_script)
    }
  end

  def sample_protocol_params do
    %ProtocolParams{
      min_fee_A: 10,
      min_fee_B: 100,
      execution_costs: %ExecutionUnitPrice{
        mem_price: {50, 20},
        step_price: {60, 20}
      },
      collateral_percentage: 150,
      max_collateral_inputs: 10,
      min_fee_ref_script_cost_per_byte: 100,
      ada_per_utxo_byte: 60
    }
  end

  def sample_native_script do
    NativeScript.from_json(@script_all)
  end

  def sample_plutus_script do
    Script.new("4e4d01000033222220051200120011", :plutus_v1)
  end

  def sample_address, do: @sample_addr
end
