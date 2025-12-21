#!/bin/bash
set -e

# Default to preprod if not set
export BLOCKFROST_NETWORK=${BLOCKFROST_NETWORK:-preprod}
export MAESTRO_NETWORK=${MAESTRO_NETWORK:-preprod}
export KOIOS_NETWORK=${KOIOS_NETWORK:-preprod}
export TEST_ADDRESS=""
export TEST_SIGNING_KEY=""

if [ -z "$TEST_ADDRESS" ] || [ -z "$TEST_SIGNING_KEY" ]; then
    echo "Error: TEST_ADDRESS and TEST_SIGNING_KEY env vars must be set."
    exit 1
fi

echo "Running Provider Integration Tests (Simple Mint)..."
echo "Target Address: $TEST_ADDRESS"

# Function to run the mint script
run_mint_test() {
    local provider=$1
    echo "------------------------------------------------"
    echo "Running Simple Mint on Provider: $provider"
    export PROVIDER=$provider
    mix run examples/simple/simple_mint.exs
}

# Blockfrost
if [ -n "$BLOCKFROST_PROJECT_ID" ]; then
    run_mint_test "blockfrost"
else
    echo "Skipping Blockfrost (BLOCKFROST_PROJECT_ID not set)"
fi

# Maestro
if [ -n "$MAESTRO_API_KEY" ]; then
    run_mint_test "maestro"
else
    echo "Skipping Maestro (MAESTRO_API_KEY not set)"
fi

# Koios
# Koios relies on public tier or key. We run it validation to ensure code path works.
echo "------------------------------------------------"
echo "Running Simple Mint on Provider: koios"
export PROVIDER="koios"
mix run examples/simple/simple_mint.exs

echo "------------------------------------------------"
echo "All Provider Tests Completed."
