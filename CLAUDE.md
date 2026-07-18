# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sutra (`sutra_cardano`) is an Elixir offchain transaction builder framework/SDK for Cardano. It provides a pipe-friendly, component-based API to construct, sign, and submit transactions, with first-class Plutus script support (V1–V4) and pluggable chain data providers. UPLC (Untyped Plutus Core) script evaluation is delegated to a Rust NIF via Rustler (`native/sutra_uplc`).

## Commands

```bash
mix deps.get                       # Install dependencies
mix compile --warnings-as-errors   # Compile (CI treats warnings as errors)
mix test                           # Run all tests
mix test path/to/file_test.exs     # Run a single test file
mix test path/to/file_test.exs:42  # Run the test at line 42
mix format                         # Format code
mix format --check-formatted       # Verify formatting (CI gate)
mix credo --strict                 # Static analysis / consistency (CI gate)
mix run examples/simple/simple_mint.exs   # Run an example script
```

The CI pipeline (`.github/workflows/elixir.yaml`) runs, in order: compile with `--warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`, then `mix test`. Match all four before considering a change done.

- **Toolchain**: Elixir 1.19.4 / Erlang OTP 28.3 (see `.tool-versions`). `libsodium-dev` and a Rust toolchain are required (the Rust NIF builds as part of `mix compile`).
- **Integration tests** require a running **Yaci DevKit** local devnet (`yaci-devkit up --enable-yaci-store`, general API on `:8080`, admin API on `:10000`). Tests using `Sutra.PrivnetTest` / `Sutra.Provider.Yaci` will fail without it.

## Architecture

The transaction lifecycle flows: **domain types → builder pipeline → CBOR body → sign → provider submit**.

### Entry point and builder pipeline
- `Sutra` (`lib/sutra.ex`) is the public entry point; it `defdelegate`s everything to `Sutra.Cardano.Transaction.TxBuilder`. When adding a user-facing builder function, add it to `TxBuilder` and delegate from `Sutra`.
- `Sutra.Cardano.Transaction.TxBuilder` (`lib/sutra/cardano/transaction/tx_builder.ex`) is the core. Transactions are built by piping through `new_tx() |> add_input/add_output/... |> build_tx!() |> sign_tx() |> submit_tx()`. `build_tx!/2` performs coin selection, fee calculation, and change handling; `build_tx` returns `{:ok, tx}` / `{:error, reason}` while `build_tx!` raises. Supporting logic lives in `tx_builder/` (`collateral.ex`, `tx_config.ex`, `certificate_helper.ex`, `internal.ex`, `error.ex`).
- **`add_guard` replaces the deprecated `add_signer`** — guards represent required-signer / script-require constraints (see recent governance/certificate commits). Prefer `add_guard` when touching signer requirements.

### Cardano domain types (`lib/sutra/cardano/`)
Core value objects, each with CBOR encode/decode: `Transaction`, `transaction/tx_body.ex` (`TxBody`), `Address` (+ `address/parser.ex`), `Asset`, `Script` (+ `script/native_script.ex`), `transaction/{input,output,output_reference,datum,witness,certificate}.ex`. Governance lives under `cardano/gov/` (`gov_action.ex`, `proposal_procedure.ex`) plus `cardano/gov.ex` (voting), and shared sub-objects under `cardano/common/` (`drep.ex`, `stake_pool.ex`, `pool_relay.ex`). The target ledger era is **Dijkstra** (`cddl/dijkstra.cddl` is the authoritative wire format; era-specific fields like reference-script cost, size limits, and `account_balance_interval.ex` follow it).

### Plutus Data mapping (`lib/sutra/data.ex` + `lib/sutra/data/`)
A macro-heavy system mapping Elixir structs to Plutus Data (Constr) encodings. When defining any type that crosses the on-chain boundary:
- `use Sutra.Data`, then `defdata` for product types (Aiken objects) and `defenum` for sum types. Fields declared via `data :name, :type` / `field :variant, :type`; encoding can be overridden per-field with `encode_with:` / `decode_with:`.
- The macro machinery is in `data/macro_helper/` (`object_macro.ex`, `enum_macro.ex`, `type_macro.ex`, `schema_builder.ex`); CBOR primitives in `data/cbor.ex`, `data/plutus.ex`, `data/decoder.ex`, `data/option.ex`.

### Blueprint codegen (`lib/sutra/cardano/blueprint/`)
Parses Aiken CIP-57 `blueprint.json` and generates typed Elixir modules. Driven by the `mix sutra.blueprint.gen` task (`lib/mix/tasks/sutra.blueprint.gen.ex`); `blueprint/parser.ex` + `blueprint/code_generator.ex` do the work.

### Providers (`lib/sutra/provider.ex` + `lib/sutra/provider/`)
`Sutra.Provider` is a behaviour for fetching chain data (UTxOs, protocol params) and submitting txs. Implementations: `blockfrost/`, `maestro/`, `koios/`, `kupogmios/` (Kupo+Ogmios), and `yaci/` (local dev). Each has a paired `client.ex` (HTTP) and provider module. Select via `use_provider(builder, Provider)` or `config :sutra, :provider, Sutra.Provider.Yaci`.

### UPLC / Rust NIF (`lib/sutra/uplc.ex` + `native/sutra_uplc/`)
`Sutra.Uplc` is the interface to the Rust-based UPLC evaluator used for phase-2 validation and script execution-cost estimation. Changes to `native/sutra_uplc` (a Cargo crate) recompile as part of `mix compile`.

## Conventions

- **Hex / CBOR / binary conversions** are pervasive — reuse helpers in `Sutra.Utils` (`lib/sutra/cardano/utils.ex`), `Sutra.Data.Cbor`, and the `CBOR` dep rather than hand-rolling.
- **Round-trip tests**: domain types are expected to encode↔decode losslessly. New wire types should have a round-trip test mirroring existing ones under `test/sutra/cardano/`.
- **Test layout**: unit/serialization tests under `test/sutra/...` mirror `lib/`; end-to-end transaction flows under `test/sutra/tx_examples/`; shared helpers/fixtures in `test/support/` and `test/fixture/` (compiled only in `:test`, see `elixirc_paths` in `mix.exs`). `Sutra.PrivnetTest` provides `with_new_wallet/1` and `await_tx/1` for devnet integration tests.
- **Docs surface**: only a curated subset of modules is published to HexDocs (`filter_modules` regex in `mix.exs`); guides live in `guides/` and are wired into `docs`.
