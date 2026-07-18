defmodule Sutra.Cardano.Gov.ProposalProcedure do
  @moduledoc """
    A governance proposal (Dijkstra/Conway `proposal_procedure`, transaction
    body field 20):

        proposal_procedure = [deposit, reward_account, gov_action, anchor]

    The `deposit` is refunded to `reward_account` once the action is enacted or
    expires. `gov_action` is one of `Sutra.Cardano.Gov.GovAction`'s structs.
  """

  use TypedStruct

  alias Sutra.Cardano.Asset
  alias Sutra.Cardano.Gov.GovAction
  alias Sutra.Data.Cbor

  import Sutra.Data.Cbor, only: [extract_value!: 1]

  typedstruct do
    field(:deposit, Asset.t())
    field(:reward_account, String.t(), enforce: true)
    field(:gov_action, any(), enforce: true)
    field(:anchor, %{url: String.t(), hash: String.t()}, enforce: true)
  end

  def decode([deposit, reward_account, gov_action, anchor]) do
    %__MODULE__{
      deposit: Asset.from_lovelace(deposit),
      reward_account: extract_value!(reward_account),
      gov_action: GovAction.decode(gov_action),
      anchor: decode_anchor(anchor)
    }
  end

  def to_cbor(%__MODULE__{} = procedure) do
    [
      Asset.to_cbor(procedure.deposit),
      Cbor.as_byte(procedure.reward_account),
      GovAction.to_cbor(procedure.gov_action),
      encode_anchor(procedure.anchor)
    ]
  end

  defp decode_anchor([url, hash]), do: %{url: url, hash: extract_value!(hash)}

  defp encode_anchor(%{url: url, hash: hash}), do: [url, Cbor.as_byte(hash)]
end
