#!/bin/bash
# export-vm.sh - Generic script to export VM from ESXi using ovftool
#
# Usage: ./export-vm.sh <esxi-host> <vm-name> [output-dir]
#
# Prerequisites:
# - ovftool installed (download from VMware)
# - ESXI_USER and ESXI_PASSWORD environment variables set
#
# Example:
#   export ESXI_USER=root
#   export ESXI_PASSWORD=mypassword
#   ./export-vm.sh 192.168.1.100 my-linux-vm ./exported

set -e

# Parse arguments
ESXI_HOST="$1"
VM_NAME="$2"
OUTPUT_DIR="${3:-./exported}"

if [ -z "$ESXI_HOST" ] || [ -z "$VM_NAME" ]; then
    echo "Usage: $0 <esxi-host> <vm-name> [output-dir]"
    echo ""
    echo "Environment variables:"
    echo "  ESXI_USER     - ESXi username (default: root)"
    echo "  ESXI_PASSWORD - ESXi password (will prompt if not set)"
    echo ""
    echo "Example:"
    echo "  export ESXI_USER=root"
    echo "  export ESXI_PASSWORD=mypassword"
    echo "  $0 192.168.1.100 my-linux-vm ./exported"
    exit 1
fi

ESXI_USER="${ESXI_USER:-root}"

echo "=============================================="
echo "VMware OVA Export"
echo "=============================================="
echo "Host: $ESXI_HOST"
echo "User: $ESXI_USER"
echo "VM: $VM_NAME"
echo "Output: $OUTPUT_DIR"
echo ""

# Check ovftool
if ! command -v ovftool &> /dev/null; then
    echo "ERROR: ovftool not found in PATH"
    echo ""
    echo "Download ovftool from:"
    echo "  https://developer.vmware.com/web/tool/ovf/"
    echo ""
    echo "Installation:"
    echo "  Linux: chmod +x VMware-ovftool-*.bundle && sudo ./VMware-ovftool-*.bundle"
    echo "  macOS: Mount DMG and copy to /Applications"
    echo "  Windows: Run installer, add to PATH"
    exit 1
fi

echo "ovftool version: $(ovftool --version | head -1)"
echo ""

# Prompt for password if not set
if [ -z "$ESXI_PASSWORD" ]; then
    echo -n "Enter ESXi password for $ESXI_USER@$ESXI_HOST: "
    read -s ESXI_PASSWORD
    echo ""
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build source URI
# For standalone ESXi (no vCenter), the path is just the VM name
SOURCE_URI="vi://${ESXI_USER}:${ESXI_PASSWORD}@${ESXI_HOST}/${VM_NAME}"

# Output file
OUTPUT_FILE="$OUTPUT_DIR/${VM_NAME}.ova"

echo "Starting export..."
echo "Source: vi://${ESXI_USER}:****@${ESXI_HOST}/${VM_NAME}"
echo "Target: $OUTPUT_FILE"
echo ""
echo "NOTE: The VM should be powered off for a consistent export."
echo "      If the VM is running, you may get warnings or inconsistent data."
echo ""

# Run ovftool
# Options:
#   --noSSLVerify : Skip SSL certificate verification (for self-signed certs)
#   --diskMode=thin : Export as thin-provisioned (smaller file)
#   --X:logFile : Log to file for debugging
#   --X:logLevel : Verbose logging

ovftool \
    --noSSLVerify \
    --diskMode=thin \
    --X:logFile="$OUTPUT_DIR/ovftool.log" \
    --X:logLevel=verbose \
    "$SOURCE_URI" \
    "$OUTPUT_FILE"

# Check result
if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo ""
    echo "=============================================="
    echo "Export Complete!"
    echo "=============================================="
    echo "Output file: $OUTPUT_FILE"
    echo "File size: $FILE_SIZE"
    echo ""
    echo "Next steps:"
    echo "  1. Upload to S3: aws s3 cp $OUTPUT_FILE s3://your-bucket/"
    echo "  2. Import as AMI: aws ec2 import-image ..."
else
    echo ""
    echo "ERROR: Export failed. Check $OUTPUT_DIR/ovftool.log for details."
    exit 1
fi
