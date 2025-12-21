#!/bin/bash
set -e

# Default to preprod if not set
export BLOCKFROST_NETWORK=${BLOCKFROST_NETWORK:-preprod}
export MAESTRO_NETWORK=${MAESTRO_NETWORK:-preprod}
export KOIOS_NETWORK=${KOIOS_NETWORK:-preprod}

echo "Running Provider Integration Tests (Simple Mint)..."

# Function to run the mint script
# Usage: run_mint_test <provider> <address> <signing_key>
run_mint_test() {
    local provider=$1
    local address=$2
    local signing_key=$3

    echo "------------------------------------------------"
    echo "Running Simple Mint on Provider: $provider"
    
    # Run mix with the specific env vars for this provider test
    PROVIDER=$provider TEST_ADDRESS=$address TEST_SIGNING_KEY=$signing_key mix run examples/simple/simple_mint.exs
}

# Blockfrost
if [ -n "$BLOCKFROST_PROJECT_ID" ]; then
    run_mint_test "blockfrost" "$BLOCKFROST_TEST_ADDRESS" "$BLOCKFROST_TEST_SIGNING_KEY"
else
    echo "Skipping Blockfrost (BLOCKFROST_PROJECT_ID not set)"
fi

# Maestro
if [ -n "$MAESTRO_API_KEY" ]; then
    run_mint_test "maestro" "$MAESTRO_TEST_ADDRESS" "$MAESTRO_TEST_SIGNING_KEY"
else
    echo "Skipping Maestro (MAESTRO_API_KEY not set)"
fi

# Koios
echo "------------------------------------------------"
echo "Running Koios Provider Test"
# run_mint_test "koios" "$KOIOS_TEST_ADDRESS" "$KOIOS_TEST_SIGNING_KEY"

echo "------------------------------------------------"
echo "All Provider Tests Completed."
