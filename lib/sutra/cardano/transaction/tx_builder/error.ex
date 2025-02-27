defmodule Sutra.Cardano.Transaction.TxBuilder.Error do
  @moduledoc """
    Error types for Transaction Builder
  """

  alias Sutra.Cardano.Transaction

  defmodule NoScriptWitness do
    @moduledoc """
      Error types when Script Witness is not found in Tx
    """

    defstruct [:info, :reason]

    @doc false
    def new(script_hash) do
      reason = """
        No Script witness found for Script #{script_hash}

        Either AttachScript or provide script in Reference Input
      """

      %__MODULE__{
        info: %{script_hash: script_hash},
        reason: reason
      }
    end
  end

  defmodule ScriptEvaluationFailed do
    @moduledoc """
      Error type when Script Evaluation is failed
    """

    defstruct [:reason, :tx]

    @doc false
    def new(msg) do
      %__MODULE__{
        reason: msg
      }
    end
  end

  defmodule NoSuitableCollateralUTXO do
    @moduledoc """
      Error type when collateral utxo cannot be fullfilled
    """

    defstruct [:reason, :tx, :info]

    @doc false
    def new(%Transaction{} = tx, required_collateral) do
      reason = """
        Couldn't find utxos in wallet to cover collateral for: #{required_collateral}
      """

      %__MODULE__{
        tx: tx,
        reason: reason,
        info: %{required_collateral: required_collateral}
      }
    end
  end

  defmodule CannotBalanceTx do
    @moduledoc """
      Error type when collateral utxo cannot be fullfilled
    """

    defstruct [:reason, :info]

    @doc false
    def new(tot_asset, msg \\ nil) do
      reason = """
        Couldn't find utxos to cover \n #{inspect(tot_asset)}
      """

      %__MODULE__{
        reason: msg || reason,
        info: %{tot_asset: tot_asset}
      }
    end
  end

  defmodule ConfigError do
    @moduledoc false

    defstruct [:reason, :field]

    def new(field, reason) do
      %__MODULE__{
        reason: reason,
        field: field
      }
    end
  end
end
