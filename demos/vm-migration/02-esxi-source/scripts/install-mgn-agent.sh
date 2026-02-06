#!/bin/bash
# install-mgn-agent.sh - Generic MGN agent installation script for Linux
#
# Usage: sudo ./install-mgn-agent.sh <region> <access-key-id> <secret-access-key>
#
# Example:
#   sudo ./install-mgn-agent.sh us-east-1 AKIAXXXXXXXX secretkey123

set -e

# Parse arguments
REGION="${1:-us-east-1}"
ACCESS_KEY_ID="$2"
SECRET_ACCESS_KEY="$3"

if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ]; then
    echo "Usage: sudo $0 <region> <access-key-id> <secret-access-key>"
    echo ""
    echo "Example:"
    echo "  sudo $0 us-east-1 AKIAXXXXXXXX mysecretkey"
    exit 1
fi

echo "=============================================="
echo "AWS MGN Agent Installation"
echo "=============================================="
echo "Region: $REGION"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    echo "Detected OS: $OS $VERSION"
else
    echo "WARNING: Cannot detect OS. Proceeding anyway..."
    OS="unknown"
fi

# Check required tools
echo "Checking prerequisites..."
for cmd in curl wget; do
    if ! command -v $cmd &> /dev/null; then
        echo "Installing $cmd..."
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            apt-get update && apt-get install -y $cmd
        elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "amzn" ]; then
            yum install -y $cmd
        fi
    fi
done

# Test network connectivity
echo ""
echo "Testing network connectivity to AWS..."
MGN_ENDPOINT="https://mgn.${REGION}.amazonaws.com"

if curl -s --connect-timeout 10 "$MGN_ENDPOINT" > /dev/null 2>&1; then
    echo "✓ Can reach MGN endpoint: $MGN_ENDPOINT"
else
    echo "✗ Cannot reach MGN endpoint: $MGN_ENDPOINT"
    echo ""
    echo "Please check:"
    echo "  1. Internet connectivity"
    echo "  2. Firewall rules (outbound TCP 443 required)"
    echo "  3. DNS resolution"
    exit 1
fi

# Download agent installer
AGENT_URL="https://aws-application-migration-service-${REGION}.s3.${REGION}.amazonaws.com/latest/linux/aws-replication-installer-init"
INSTALLER_PATH="/tmp/aws-replication-installer-init"

echo ""
echo "Downloading MGN agent installer..."
if wget -q -O "$INSTALLER_PATH" "$AGENT_URL"; then
    echo "✓ Downloaded agent installer"
    chmod +x "$INSTALLER_PATH"
else
    echo "✗ Failed to download agent installer"
    echo "URL: $AGENT_URL"
    exit 1
fi

# Install the agent
echo ""
echo "Installing MGN agent..."
echo "(This may take a few minutes)"
echo ""

"$INSTALLER_PATH" \
    --region "$REGION" \
    --aws-access-key-id "$ACCESS_KEY_ID" \
    --aws-secret-access-key "$SECRET_ACCESS_KEY" \
    --no-prompt

# Verify installation
echo ""
echo "=============================================="
echo "Verifying installation..."
echo "=============================================="

sleep 5  # Give agent time to start

if systemctl is-active --quiet aws-replication-agent 2>/dev/null; then
    echo "✓ MGN agent is running"
    echo ""
    systemctl status aws-replication-agent --no-pager -l
else
    echo "⚠ Agent service status unknown"
    echo "Check with: systemctl status aws-replication-agent"
fi

echo ""
echo "=============================================="
echo "Installation Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Monitor replication progress in AWS Console:"
echo "   https://${REGION}.console.aws.amazon.com/mgn/home?region=${REGION}#/sourceServers"
echo ""
echo "2. Wait for initial sync to complete"
echo ""
echo "3. Launch test instance from MGN console"
echo ""
echo "Troubleshooting:"
echo "  Logs: journalctl -u aws-replication-agent -f"
echo "  Status: systemctl status aws-replication-agent"
