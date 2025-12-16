# Sutra SDK AI Instructions

Sutra is an Elixir-based offchain transaction builder framework for Cardano. It leverages Rust (via Rustler) for UPLC evaluation and provides a high-level API for constructing, signing, and submitting transactions.

## Architecture & Core Components

- **Core Domain (`lib/sutra/cardano/`)**: Contains the fundamental Cardano types.
  - `Transaction`: Represents the full transaction structure.
  - `TxBody`: The transaction body.
  - `Address`, `Asset`, `Script`: Domain objects.
- **Data Mapping (`lib/sutra/data.ex`)**: A macro-heavy system for defining Elixir structs that map to Plutus Data encodings.
  - Use `defdata` to define structs that need to be serialized to/from Plutus Data.
  - Use `defenum` for sum types.
- **Providers (`lib/sutra/provider.ex`)**: Defines the `Sutra.Provider` behaviour for fetching chain data (UTxOs, protocol params).
  - Implementations: `YaciProvider`, `KoiosProvider`, `Kupogmios`.
- **UPLC (`lib/sutra/uplc.ex`)**: Interface to the Rust-based UPLC evaluator (`native/sutra_uplc`). Used for phase-2 validation and script execution cost estimation.

## Transaction Building Workflow

Transactions are built using a pipeline pattern centered around `Sutra.Cardano.Transaction.TxBuilder`.

```elixir
import Sutra.Cardano.Transaction.TxBuilder

new_tx()
|> add_output(address, amount, datum)
|> add_input(utxo, witness: script, redeemer: redeemer_data)
|> build_tx!(wallet_address: change_address)
|> sign_tx([signing_key])
|> submit_tx()
```

- **`new_tx()`**: Initializes a builder struct.
- **`add_output/3`**: Adds a transaction output.
- **`add_input/3`**: Adds an input. For script inputs, provide `witness` (the script) and `redeemer`.
- **`build_tx!/2`**: Balances the transaction (coin selection), calculates fees, and handles change.
- **`sign_tx/2`**: Signs the transaction with the provided keys.
- **`submit_tx/1`**: Submits via the configured provider.

## Testing Patterns

- **Integration Tests**: Use `Sutra.PrivnetTest` for tests requiring a local private network (Yaci).
  - Use `with_new_wallet(fn wallet -> ... end)` to get a funded wallet for testing.
  - Use `await_tx(tx_id)` to wait for confirmation.
  - Use `YaciProvider` to query chain state in tests.
- **Unit Tests**: Located in `test/sutra/cardano/`. Focus on type serialization and logic without chain interaction.

## Conventions

- **Plutus Data**: When defining types that interact with on-chain scripts, always use `use Sutra.Data` and `defdata`.
- **Hex/CBOR**: The codebase frequently converts between raw binary, Hex strings, and CBOR. Use `Sutra.Utils` or `CBOR` module helpers.
- **Error Handling**: `build_tx` returns `{:ok, tx}` or `{:error, reason}`. `build_tx!` raises on error.
- **Rust NIFs**: Changes to `native/sutra_uplc` require recompiling the Rust crate.

## Key Files
- `lib/sutra/cardano/transaction/tx_builder.ex`: The core transaction building logic.
- `lib/sutra/data.ex`: The `defdata` macro definition.
- `test/sutra/tx_examples/`: Examples of complex transaction flows (minting, spending from scripts).
