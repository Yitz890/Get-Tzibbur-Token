#!/bin/bash

# Ensure jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed."
    echo "Please install it using your package manager (e.g., 'sudo apt install jq' or 'brew install jq')"
    exit 1
fi

# Create secure temporary files
CHALLENGE_FILE=$(mktemp)
VERIFY_FILE=$(mktemp)

# Ask for user input
read -p "Whats your Tzibbur nickname: " NICKNAME
read -p "Whats your phone number (with +, e.g. +15550100123): " PHONE

echo "Sending verification code..."

# Step 1: Request SMS code
curl -s -X POST "https://api.tzibbur.me/v1/auth/start" \
    -H "Content-Type: application/json" \
    -d "{\"phone\": \"$PHONE\", \"displayName\": \"$NICKNAME\", \"region\": \"US\", \"platform\": \"android\", \"deviceModel\": \"bash\"}" > "$CHALLENGE_FILE"

# Extract challengeId using jq (robust JSON parsing)
# -r outputs raw text instead of quoted strings, // empty prevents literal "null" strings
CHALLENGE_ID=$(jq -r '.challengeId // empty' "$CHALLENGE_FILE")

if [ -z "$CHALLENGE_ID" ]; then
    echo "Failed to get challenge ID. Response was:"
    cat "$CHALLENGE_FILE"
    echo ""
    read -p "Press Enter to exit..."
    rm -f "$CHALLENGE_FILE" "$VERIFY_FILE"
    exit 1
fi

echo "Code sent! Check your SMS for the 6-digit code."

# Ask for the code
read -p "Enter the 6-digit verification code: " CODE

echo "Verifying..."

# Step 2: Verify code
curl -s -X POST "https://api.tzibbur.me/v1/auth/verify" \
    -H "Content-Type: application/json" \
    -d "{\"challengeId\": \"$CHALLENGE_ID\", \"code\": \"$CODE\", \"phone\": \"$PHONE\", \"displayName\": \"$NICKNAME\", \"region\": \"US\", \"platform\": \"android\", \"deviceModel\": \"bash\"}" > "$VERIFY_FILE"

# Extract token using jq
TOKEN=$(jq -r '.token // empty' "$VERIFY_FILE")

# Check if token is empty
if [ -z "$TOKEN" ]; then
    echo "Verification failed. Response was:"
    cat "$VERIFY_FILE"
    echo ""
    read -p "Press Enter to exit..."
    rm -f "$CHALLENGE_FILE" "$VERIFY_FILE"
    exit 1
fi

# ------------------------------------------
# SUCCESS: Show token and PAUSE
# ------------------------------------------
echo ""
echo "========================================"
echo "Your Tzibbur access token is:"
echo "$TOKEN"
echo "========================================"
echo ""
echo "Copy this token now. You will need it to send messages."
echo ""

# First pause - keeps window open so you can copy the token
read -p "Press Enter to clean up temporary files..."

# Clean up
rm -f "$CHALLENGE_FILE" "$VERIFY_FILE"

# Second pause - keeps window open until you manually close it
echo ""
echo "All done."
read -p "Press Enter to close this window..."
