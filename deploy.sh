#!/bin/bash
# Deploy HomeButler to jailbroken iPad
# Usage: ./deploy.sh
#
# Configure your iPad's IP address below, or set IPAD_IP environment variable

IPAD_IP="${IPAD_IP:-YOUR_IPAD_IP}"
IPAD_PASS="${IPAD_PASS:-alpine}"

if [ "$IPAD_IP" = "YOUR_IPAD_IP" ]; then
    echo "Error: Please set your iPad's IP address"
    echo "Edit deploy.sh and replace YOUR_IPAD_IP, or run:"
    echo "  IPAD_IP=192.168.1.xxx ./deploy.sh"
    exit 1
fi
SSH_OPTS="-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no"

echo "Building HomeButler..."
./build_ipa.sh

echo ""
echo "Deploying to iPad at $IPAD_IP..."
echo ""

# Extract the app
rm -rf Payload
unzip -o HomeButler.ipa

# Copy to iPad
echo "Copying app to iPad..."
sshpass -p "$IPAD_PASS" scp $SSH_OPTS -r Payload/HomeButler.app root@$IPAD_IP:/Applications/

# Set permissions and refresh
echo "Setting permissions and refreshing UI cache..."
sshpass -p "$IPAD_PASS" ssh $SSH_OPTS root@$IPAD_IP "chmod -R 755 /Applications/HomeButler.app && chown -R root:wheel /Applications/HomeButler.app && uicache -p /Applications/HomeButler.app"

# Cleanup
rm -rf Payload

echo ""
echo "Done! HomeButler updated on iPad."
