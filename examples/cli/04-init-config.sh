#!/usr/bin/env bash
# Example 4: Initialize configuration

set -e

echo "========================================="
echo "Ananke Example 4: Initialize Config"
echo "========================================="
echo ""

CONFIG_FILE="/tmp/.ananke.toml"

echo "1. Create default configuration file"
echo "Command: ananke init --config $CONFIG_FILE"
echo ""
ananke init --config "$CONFIG_FILE"
echo ""

echo "2. View created configuration"
echo "Contents of $CONFIG_FILE:"
echo ""
cat "$CONFIG_FILE"
echo ""

echo "3. Initialize with Modal endpoint"
MODAL_ENDPOINT="https://my-app.modal.run"
CONFIG_FILE2="/tmp/.ananke2.toml"
echo "Command: ananke init --config $CONFIG_FILE2 --modal-endpoint $MODAL_ENDPOINT --force"
echo ""
ananke init --config "$CONFIG_FILE2" --modal-endpoint "$MODAL_ENDPOINT" --force
echo ""

echo "4. View configuration with Modal endpoint"
echo "Contents of $CONFIG_FILE2:"
echo ""
cat "$CONFIG_FILE2"
echo ""

echo "========================================="
echo "Example complete!"
echo "========================================="
