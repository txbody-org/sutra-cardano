defmodule Sutra.ProtocolParams do
  @moduledoc """
    Protocol params Helper functions
  """
  alias Sutra.Cardano.Gov.CostModels
  alias Sutra.Common.{ExecutionUnitPrice, ExecutionUnits}

  use TypedStruct

  typedstruct do
    # -- 0
    field(:min_fee_A, pos_integer())

    # -- 1
    field(:min_fee_B, pos_integer())

    ## -- 2
    field(:max_body_block_size, pos_integer())

    ## -- 3
    field(:max_transaction_size, pos_integer())

    ## -- 4
    field(:max_block_header_size, pos_integer())

    ## -- 5
    field(:key_deposit, pos_integer())

    ## -- 6
    field(:pool_deposit, pos_integer())

    ## -- 7
    field(:maximum_epoch, pos_integer())

    ## -- 8
    field(:desired_number_of_stake_pool, pos_integer())

    ## -- 9
    field(:pool_pledge_influence, Sutra.Common.ratio())

    ## -- 10
    field(:expansion_rate, Sutra.Common.ratio())

    ## -- 11
    field(:treasury_growth_rate, Sutra.Common.ratio())

    ## -- 16
    field(:min_pool_cost, pos_integer())

    ## -- 17
    field(:ada_per_utxo_byte, pos_integer())

    ## -- 18
    field(:cost_models, CostModels.t())

    ## -- 19
    field(:execution_costs, ExecutionUnitPrice.t())

    ## -- 20
    field(:max_tx_ex_units, ExecutionUnits.t())

    ## -- 21
    field(:max_block_ex_units, ExecutionUnits.t())

    ## -- 22
    field(:max_value_size, :integer)

    ## -- 23
    field(:collateral_percentage, :integer)

    ## -- 24
    field(:max_collateral_inputs, :integer)

    ## -- 25 FIXME: use propor types
    field(:pool_voting_thresholds, any())

    ## -- 26 FIXME: use propor types
    field(:drep_voting_thresholds, any())

    ## -- 27
    field(:min_committee_size, integer())

    ## -- 28
    field(:committee_term_limit, pos_integer())

    ## -- 29
    field(:gov_action_validity_period, pos_integer())

    ## -- 30
    field(:gov_action_deposit, pos_integer())

    ## -- 31
    field(:drep_deposit, pos_integer())

    ## -- 32
    field(:drep_inactivity_period, pos_integer())

    ## -- 33
    field(:min_fee_ref_script_cost_per_byte, pos_integer())
  end
end
