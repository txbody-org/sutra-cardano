defmodule Sutra.TxExamples.Gov.VoteTest do
  @moduledoc false

  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Gov
  alias Sutra.Cardano.Gov.GovAction
  alias Sutra.Cardano.Transaction

  use Sutra.PrivnetTest

  setup_all %{} do
    set_yaci_provider_env()

    # A DRep registration deposit (500 ADA) plus a governance-action deposit
    # (1000 ADA) far exceed the default `with_new_wallet` top-up, so fund a
    # dedicated wallet with enough ADA to register a DRep and propose an action.
    with_new_wallet(fn %{signing_key: skey, address: addr} ->
      load_ada(addr, [2_000])

      # Register the wallet's stake credential as a DRep and, in the same tx,
      # submit an Info governance action. The action id is this tx's id at
      # proposal index 0.
      # The proposal's deposit-return account must be a registered stake
      # credential, so register the wallet's stake credential alongside the DRep.
      #
      # Deposits are passed explicitly: the Yaci admin protocol-parameters
      # endpoint reports `drep_deposit`/`gov_action_deposit` as null, so the
      # build-time auto-fill can't derive them. These match the devnet genesis.
      tx =
        Sutra.new_tx()
        |> Sutra.register_stake_credential(addr)
        |> Sutra.register_drep(addr, deposit: 500_000_000)
        |> Sutra.propose(GovAction.info(),
          reward_account: reward_address(addr),
          deposit: 1_000_000_000,
          anchor: %{
            url: "https://example.com/vote-test.json",
            hash: String.duplicate("00", 32)
          }
        )
        |> Sutra.build_tx!(wallet_address: [addr])

      action_tx_id =
        tx
        |> Sutra.sign_tx([skey])
        |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
        |> Sutra.submit_tx()

      await_tx(action_tx_id)

      {:ok, wallet_address: addr, skey: skey, action_tx_id: action_tx_id}
    end)
  end

  describe "Vote on a governance action" do
    test "a registered DRep casts a yes vote on an Info action", %{
      wallet_address: addr,
      skey: skey,
      action_tx_id: action_tx_id
    } do
      drep_voter = Gov.drep_voter(addr.stake_credential)
      action = Gov.gov_action_id(action_tx_id, 0)

      assert {:ok, tx} =
               Sutra.new_tx()
               |> Sutra.vote(drep_voter, action, :yes)
               |> Sutra.build_tx(wallet_address: [addr])

      assert tx_id =
               Sutra.sign_tx(tx, [skey])
               |> Sutra.sign_tx_with_raw_extended_key(skey.stake_key)
               |> Sutra.submit_tx()

      await_tx(tx_id)

      assert Transaction.tx_id(tx) == tx_id
    end
  end

  # Build the reward (stake) address for a base address, reusing its stake
  # credential — used as the deposit-return account for the proposal.
  defp reward_address(%Address{network: network, stake_credential: stake_credential}) do
    %Address{
      network: network,
      address_type: :reward,
      payment_credential: nil,
      stake_credential: stake_credential
    }
  end
end
