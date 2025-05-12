#!/bin/bash

# Check for KEY_PATH
if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi

# Check for at least 1 argument (bastion IP)
if [ -z "$1" ]; then
  echo "Please provide bastion IP address"
  echo "hi"
  exit 5
fi

BASTION_IP="$1"
TARGET_IP="$2"
shift 2

# Case 1: Connect to polybot instance via bastion
if [ -n "$TARGET_IP" ]; then
  ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$BASTION_IP" ubuntu@"$TARGET_IP" "$@"

# Case 2: Connect to bastion only
else
  ssh -i "$KEY_PATH" ubuntu@"$BASTION_IP"
fi
