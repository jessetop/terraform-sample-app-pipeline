#!/bin/bash
# upload-to-s3.sh - Upload OVA/VMDK to S3 with progress
#
# Usage: ./upload-to-s3.sh <local-file> <s3-bucket> [s3-key]
#
# Example:
#   ./upload-to-s3.sh ./exported/my-vm.ova my-import-bucket

set -e

LOCAL_FILE="$1"
S3_BUCKET="$2"
S3_KEY="${3:-$(basename "$LOCAL_FILE")}"
REGION="${AWS_REGION:-us-east-1}"

if [ -z "$LOCAL_FILE" ] || [ -z "$S3_BUCKET" ]; then
    echo "Usage: $0 <local-file> <s3-bucket> [s3-key]"
    echo ""
    echo "Environment variables:"
    echo "  AWS_REGION - AWS region (default: us-east-1)"
    echo ""
    echo "Example:"
    echo "  $0 ./exported/my-vm.ova my-import-bucket"
    echo "  $0 ./exported/my-vm.ova my-import-bucket custom-name.ova"
    exit 1
fi

if [ ! -f "$LOCAL_FILE" ]; then
    echo "ERROR: File not found: $LOCAL_FILE"
    exit 1
fi

FILE_SIZE=$(du -h "$LOCAL_FILE" | cut -f1)
FILE_SIZE_BYTES=$(stat -f%z "$LOCAL_FILE" 2>/dev/null || stat -c%s "$LOCAL_FILE" 2>/dev/null)

echo "=============================================="
echo "S3 Upload"
echo "=============================================="
echo "File: $LOCAL_FILE"
echo "Size: $FILE_SIZE"
echo "Bucket: $S3_BUCKET"
echo "Key: $S3_KEY"
echo "Region: $REGION"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found"
    echo "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured or invalid"
    echo "Run: aws configure"
    exit 1
fi

echo "AWS Identity: $(aws sts get-caller-identity --query 'Arn' --output text)"
echo ""

# Check if bucket exists
if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$REGION" 2>/dev/null; then
    echo "ERROR: Bucket '$S3_BUCKET' does not exist or you don't have access"
    exit 1
fi

echo "Starting upload..."
echo "(Large files use multipart upload automatically)"
echo ""

# Upload with progress
# AWS CLI automatically uses multipart for files > 8MB
START_TIME=$(date +%s)

aws s3 cp "$LOCAL_FILE" "s3://$S3_BUCKET/$S3_KEY" \
    --region "$REGION" \
    --expected-size "$FILE_SIZE_BYTES"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=============================================="
echo "Upload Complete!"
echo "=============================================="
echo "Duration: ${DURATION}s"
echo "S3 URI: s3://$S3_BUCKET/$S3_KEY"
echo ""
echo "Verify upload:"
echo "  aws s3 ls s3://$S3_BUCKET/$S3_KEY"
echo ""
echo "Next step: Import as AMI"
echo "  aws ec2 import-image --disk-containers \"Description=...,Format=ova,UserBucket={S3Bucket=$S3_BUCKET,S3Key=$S3_KEY}\""
