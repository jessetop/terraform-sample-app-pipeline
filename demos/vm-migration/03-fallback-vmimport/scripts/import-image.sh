#!/bin/bash
# import-image.sh - Import OVA/VMDK from S3 as AMI
#
# Usage: ./import-image.sh <s3-bucket> <s3-key> [description]
#
# Example:
#   ./import-image.sh my-import-bucket my-vm.ova "My Linux VM from ESXi"

set -e

S3_BUCKET="$1"
S3_KEY="$2"
DESCRIPTION="${3:-Imported VM}"
REGION="${AWS_REGION:-us-east-1}"
LICENSE_TYPE="${LICENSE_TYPE:-AWS}"  # AWS or BYOL

if [ -z "$S3_BUCKET" ] || [ -z "$S3_KEY" ]; then
    echo "Usage: $0 <s3-bucket> <s3-key> [description]"
    echo ""
    echo "Environment variables:"
    echo "  AWS_REGION   - AWS region (default: us-east-1)"
    echo "  LICENSE_TYPE - AWS or BYOL (default: AWS)"
    echo ""
    echo "Example:"
    echo "  $0 my-import-bucket my-vm.ova \"My Linux VM\""
    echo "  LICENSE_TYPE=BYOL $0 my-import-bucket my-vm.ova \"RHEL VM\""
    exit 1
fi

# Detect format from file extension
FORMAT="ova"
case "$S3_KEY" in
    *.vmdk) FORMAT="vmdk" ;;
    *.vhd)  FORMAT="vhd" ;;
    *.vhdx) FORMAT="vhdx" ;;
    *.raw)  FORMAT="raw" ;;
esac

echo "=============================================="
echo "VM Import"
echo "=============================================="
echo "Source: s3://$S3_BUCKET/$S3_KEY"
echo "Format: $FORMAT"
echo "Region: $REGION"
echo "License: $LICENSE_TYPE"
echo "Description: $DESCRIPTION"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found"
    exit 1
fi

# Verify file exists in S3
echo "Verifying S3 object..."
if ! aws s3api head-object --bucket "$S3_BUCKET" --key "$S3_KEY" --region "$REGION" &>/dev/null; then
    echo "ERROR: Object not found: s3://$S3_BUCKET/$S3_KEY"
    exit 1
fi
echo "S3 object exists"
echo ""

# Start import
echo "Starting import task..."
IMPORT_RESULT=$(aws ec2 import-image \
    --region "$REGION" \
    --description "$DESCRIPTION" \
    --license-type "$LICENSE_TYPE" \
    --disk-containers "Description=$DESCRIPTION,Format=$FORMAT,UserBucket={S3Bucket=$S3_BUCKET,S3Key=$S3_KEY}" \
    --output json)

IMPORT_TASK_ID=$(echo "$IMPORT_RESULT" | grep -o '"ImportTaskId": "[^"]*"' | cut -d'"' -f4)

if [ -z "$IMPORT_TASK_ID" ]; then
    echo "ERROR: Failed to start import task"
    echo "$IMPORT_RESULT"
    exit 1
fi

echo "Import task ID: $IMPORT_TASK_ID"
echo ""
echo "=============================================="
echo "Monitoring Progress"
echo "=============================================="
echo "(Press Ctrl+C to stop monitoring - import will continue in background)"
echo ""

# Monitor loop
LAST_STATUS=""
while true; do
    TASK_INFO=$(aws ec2 describe-import-image-tasks \
        --region "$REGION" \
        --import-task-ids "$IMPORT_TASK_ID" \
        --query 'ImportImageTasks[0]' \
        --output json 2>/dev/null)

    STATUS=$(echo "$TASK_INFO" | grep -o '"Status": "[^"]*"' | head -1 | cut -d'"' -f4)
    STATUS_MSG=$(echo "$TASK_INFO" | grep -o '"StatusMessage": "[^"]*"' | cut -d'"' -f4)
    PROGRESS=$(echo "$TASK_INFO" | grep -o '"Progress": "[^"]*"' | cut -d'"' -f4)

    # Only print if status changed
    CURRENT_STATUS="$STATUS|$PROGRESS|$STATUS_MSG"
    if [ "$CURRENT_STATUS" != "$LAST_STATUS" ]; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        if [ -n "$PROGRESS" ]; then
            echo "[$TIMESTAMP] Status: $STATUS | Progress: $PROGRESS% | $STATUS_MSG"
        else
            echo "[$TIMESTAMP] Status: $STATUS | $STATUS_MSG"
        fi
        LAST_STATUS="$CURRENT_STATUS"
    fi

    # Check for completion
    if [ "$STATUS" = "completed" ]; then
        AMI_ID=$(echo "$TASK_INFO" | grep -o '"ImageId": "[^"]*"' | cut -d'"' -f4)
        echo ""
        echo "=============================================="
        echo "Import Complete!"
        echo "=============================================="
        echo "AMI ID: $AMI_ID"
        echo ""
        echo "View AMI:"
        echo "  aws ec2 describe-images --image-ids $AMI_ID --region $REGION"
        echo ""
        echo "Launch instance:"
        echo "  aws ec2 run-instances --image-id $AMI_ID --instance-type t3.medium --region $REGION ..."
        echo ""

        # Show AMI details
        aws ec2 describe-images --image-ids "$AMI_ID" --region "$REGION" \
            --query 'Images[0].{ID:ImageId,Name:Name,State:State,RootDevice:RootDeviceType}' \
            --output table

        exit 0
    fi

    # Check for failure
    if [ "$STATUS" = "deleted" ] || [ "$STATUS" = "failed" ] || [ "$STATUS" = "cancelled" ]; then
        echo ""
        echo "=============================================="
        echo "Import Failed!"
        echo "=============================================="
        echo "Status: $STATUS"
        echo "Message: $STATUS_MSG"
        echo ""
        echo "Full task details:"
        aws ec2 describe-import-image-tasks \
            --region "$REGION" \
            --import-task-ids "$IMPORT_TASK_ID"
        exit 1
    fi

    sleep 30
done
