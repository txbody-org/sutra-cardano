# Sample data
Code.eval_file("examples/setup_sample_data.exs")

alias Sutra.Cardano.Address
alias Sutra.Data
alias Sutra.Cardano.Asset
alias Sutra.Crypto.Key
alias SampleData

import Sutra.Cardano.Transaction.TxBuilder

# Use Provider
Code.eval_file("examples/setup_yaci_provider.exs")

mnemonic =
  "test test test test test test test test test test test test test test test test test test test test test test test sauce"

{:ok, root_key} = Key.root_key_from_mnemonic(mnemonic)
{:ok, extended_key} = Key.derive_child(root_key, 0, 0)

to_addr = Address.from_bech32("addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c")

{:ok, wallet_address} = Key.address(extended_key, :preprod)

IO.puts("User Address: #{Address.to_bech32(wallet_address)}")

tx_id =
  new_tx()
  |> add_output(to_addr, Asset.from_lovelace(1000), {:datum_hash, "check As Hash"})
  |> add_output(to_addr, Asset.from_lovelace(1000), {:inline_datum, SampleData.sample_info()})
  |> build_tx!(wallet_address: [wallet_address])
  |> sign_tx([extended_key])
  |> submit_tx()

IO.puts("Tx Submitted with TxId: #{tx_id}")
