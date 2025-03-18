alias Sutra.Cardano.Address
alias Sutra.Data
alias Sutra.Cardano.Asset
alias Sutra.Crypto.Key

import Sutra.Cardano.Transaction.TxBuilder

# Use Provider
Code.eval_file("examples/setup_yaci_provider.exs")

mnemonic =
  "assume pumpkin dream peace basket fire wage obscure once level prefer garden fresh more erode violin poet focus brush reflect famous neck city radar"

{:ok, root_key} = Key.root_key_from_mnemonic(mnemonic)
{:ok, extended_key} = Key.derive_child(root_key, 0, 0)

to_addr = "addr_test1vq28nc9dpkull96p5aeqz3xg2n6xq0mfdd4ahyrz4aa9rag83cs3c"

{:ok, wallet_address} = Key.address(extended_key, :preprod)

IO.puts("User Address: #{Address.to_bech32(wallet_address)}")

tx_id =
  new_tx()
  |> pay_to_address(to_addr, Asset.from_lovelace(1000),
    datum: {:as_hash, Data.encode("check As Hash")}
  )
  |> pay_to_address(to_addr, Asset.from_lovelace(1000),
    datum: {:inline, Data.encode("Inline Datum")}
  )
  |> build_tx!(wallet_address: [wallet_address])
  |> sign_tx([extended_key])
  |> submit_tx()

IO.puts("Tx Submitted for Mint with Native Script TxId: #{tx_id}")
