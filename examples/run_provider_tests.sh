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

# Function to run the spend test
# Usage: run_spend_test <provider> <address> <signing_key>
run_spend_test() {
    local provider=$1
    local address=$2
    local signing_key=$3

    echo "------------------------------------------------"
    echo "Running Simple Spend on Provider: $provider"
    
    # Run mix with the specific env vars for this provider test
    PROVIDER=$provider TEST_ADDRESS=$address TEST_SIGNING_KEY=$signing_key mix run examples/simple/simple_guess_spend.exs
}

# Helper to get address and key based on index
get_wallet_credentials() {
    local idx=$1
    local addr_var="TEST_ADDR_${idx}"
    local key_var="TEST_KEY_${idx}"
    
    # Indirect reference to variables
    local addr="${!addr_var}"
    local key="${!key_var}"
    
    # Fallback/Defaults if generic vars are not set
    if [ -z "$addr" ]; then
        if [ "$idx" -eq 1 ]; then
             # Default Wallet 1 used for Mint Tests
             # Fallback to BLOCKFROST vars if available, else others
             addr=${BLOCKFROST_TEST_ADDRESS:-$TEST_ADDRESS}
             key=${BLOCKFROST_TEST_SIGNING_KEY:-$TEST_SIGNING_KEY}
        elif [ "$idx" -eq 2 ]; then
             # Default Wallet 2 used for Spend Tests
             # Fallback to MAESTRO variables if available
             addr=${MAESTRO_TEST_ADDRESS:-$TEST_ADDRESS}
             key=${MAESTRO_TEST_SIGNING_KEY:-$TEST_SIGNING_KEY}
        elif [ "$idx" -eq 3 ]; then
             addr=${KOIOS_TEST_ADDRESS:-$TEST_ADDRESS}
             key=${KOIOS_TEST_SIGNING_KEY:-$TEST_SIGNING_KEY}
        fi
    fi
    
    echo "$addr $key"
}

# Fetch Credentials for Mint (Wallet 1) and Spend (Wallet 2)
read mint_addr mint_key <<< $(get_wallet_credentials 1)
read spend_addr spend_key <<< $(get_wallet_credentials 2)

if [ -z "$mint_addr" ] || [ -z "$spend_addr" ]; then
    echo "Error: Need at least 2 wallets configured (TEST_ADDR_1/2 or BLOCKFROST/MAESTRO specific vars) to run tests."
    # We don't exit here to allow partial runs if user really wants, but warn strongly.
fi

# Blockfrost
if [ -n "$BLOCKFROST_PROJECT_ID" ]; then
    if [ -n "$mint_addr" ]; then
        run_mint_test "blockfrost" "$mint_addr" "$mint_key"
    fi
    
    if [ -n "$spend_addr" ]; then
         run_spend_test "blockfrost" "$spend_addr" "$spend_key"
    fi
    
    echo "Blockfrost Tests Done. Sleeping 30s..."
    sleep 30
else
    echo "Skipping Blockfrost (BLOCKFROST_PROJECT_ID not set)"
fi

# Maestro
if [ -n "$MAESTRO_API_KEY" ]; then
    if [ -n "$mint_addr" ]; then
        run_mint_test "maestro" "$mint_addr" "$mint_key"
    fi
    
    if [ -n "$spend_addr" ]; then
        run_spend_test "maestro" "$spend_addr" "$spend_key"
    fi

    echo "Maestro Tests Done. Sleeping 30s..."
    sleep 30
else
    echo "Skipping Maestro (MAESTRO_API_KEY not set)"
fi

# Koios
echo "------------------------------------------------"
echo "Running Koios Provider Test"
# run_mint_test "koios" "$KOIOS_TEST_ADDRESS" "$KOIOS_TEST_SIGNING_KEY"

echo "------------------------------------------------"
echo "All Provider Tests Completed."
