#!/bin/bash
# verify-agent.sh - Verify MGN agent status and connectivity
#
# Run this on the source VM to check if the agent is working correctly

echo "=============================================="
echo "MGN Agent Verification"
echo "=============================================="
echo ""

# Check if agent service exists
if ! systemctl list-units --type=service | grep -q aws-replication-agent; then
    echo "✗ MGN agent service not found"
    echo "  The agent may not be installed. Run install-mgn-agent.sh first."
    exit 1
fi

# Check service status
echo "1. Agent Service Status:"
echo "------------------------"
if systemctl is-active --quiet aws-replication-agent; then
    echo "✓ Agent is RUNNING"
else
    echo "✗ Agent is NOT RUNNING"
    echo ""
    echo "Try restarting: sudo systemctl restart aws-replication-agent"
    echo "Check logs: journalctl -u aws-replication-agent -n 50"
fi
echo ""

# Check agent processes
echo "2. Agent Processes:"
echo "-------------------"
if pgrep -f "aws-replication" > /dev/null; then
    ps aux | grep -E "aws-replication|tapdisk" | grep -v grep
    echo ""
    echo "✓ Agent processes found"
else
    echo "✗ No agent processes found"
fi
echo ""

# Check network connectivity
echo "3. Network Connectivity:"
echo "------------------------"

# Try to determine region from agent config
REGION="us-east-1"
if [ -f /var/lib/aws-replication-agent/agent.config ]; then
    CONFIG_REGION=$(grep -oP 'region["\s:]+\K[a-z]+-[a-z]+-[0-9]+' /var/lib/aws-replication-agent/agent.config 2>/dev/null | head -1)
    if [ -n "$CONFIG_REGION" ]; then
        REGION="$CONFIG_REGION"
    fi
fi

echo "Testing connectivity to $REGION..."

# Test MGN endpoint
MGN_ENDPOINT="https://mgn.${REGION}.amazonaws.com"
if curl -s --connect-timeout 5 "$MGN_ENDPOINT" > /dev/null 2>&1; then
    echo "✓ MGN endpoint reachable: $MGN_ENDPOINT"
else
    echo "✗ Cannot reach MGN endpoint: $MGN_ENDPOINT"
fi

# Test S3 endpoint
S3_ENDPOINT="https://s3.${REGION}.amazonaws.com"
if curl -s --connect-timeout 5 "$S3_ENDPOINT" > /dev/null 2>&1; then
    echo "✓ S3 endpoint reachable: $S3_ENDPOINT"
else
    echo "✗ Cannot reach S3 endpoint: $S3_ENDPOINT"
fi
echo ""

# Check disk info
echo "4. Disk Information:"
echo "--------------------"
lsblk -d -o NAME,SIZE,TYPE,MODEL 2>/dev/null || fdisk -l 2>/dev/null | grep "Disk /"
echo ""

# Check memory
echo "5. Memory:"
echo "----------"
free -h
echo ""

# Show recent agent logs
echo "6. Recent Agent Logs:"
echo "---------------------"
if journalctl -u aws-replication-agent -n 10 --no-pager 2>/dev/null; then
    :
else
    echo "Cannot retrieve logs. Try: sudo journalctl -u aws-replication-agent"
fi
echo ""

echo "=============================================="
echo "Verification Complete"
echo "=============================================="
echo ""
echo "If replication is not progressing, check:"
echo "  1. Agent logs: journalctl -u aws-replication-agent -f"
echo "  2. AWS MGN Console for detailed status"
echo "  3. Network connectivity (ports 443 and 1500 outbound)"
