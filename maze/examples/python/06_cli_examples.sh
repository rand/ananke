#!/bin/bash
# Example 6: CLI Usage Examples
#
# This script demonstrates common CLI usage patterns for Ananke.
# Make sure to set ANANKE_MODAL_ENDPOINT before running.

set -e

echo "Ananke CLI Examples"
echo "===================="
echo

# Check if endpoint is set
if [ -z "$ANANKE_MODAL_ENDPOINT" ]; then
    echo "Error: ANANKE_MODAL_ENDPOINT not set"
    echo "Set it with: export ANANKE_MODAL_ENDPOINT=https://your-app.modal.run"
    exit 1
fi

# Example 1: Show configuration
echo "1. Show current configuration"
echo "------------------------------"
ananke config
echo

# Example 2: Health check
echo "2. Check service health"
echo "-----------------------"
ananke health
echo

# Example 3: View cache stats
echo "3. View cache statistics"
echo "------------------------"
ananke cache
echo

# Example 4: Simple generation
echo "4. Generate simple code"
echo "-----------------------"
ananke generate "def hello_world():" --max-tokens 50
echo

# Example 5: Generate with constraints (if you have a constraints.json file)
if [ -f "constraints.json" ]; then
    echo "5. Generate with constraints"
    echo "----------------------------"
    ananke generate "Create a user object:" --constraints constraints.json --max-tokens 100
    echo
fi

# Example 6: Compile constraints (if you have a constraints.json file)
if [ -f "constraints.json" ]; then
    echo "6. Compile constraints"
    echo "----------------------"
    ananke compile constraints.json --output compiled.json
    echo "Compiled constraints saved to compiled.json"
    echo
fi

# Example 7: Clear cache
echo "7. Clear cache"
echo "--------------"
ananke cache --clear
echo

echo "===================="
echo "CLI examples complete!"
