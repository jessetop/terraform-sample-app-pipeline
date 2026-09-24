#!/usr/bin/env bash
set -e

S3_BUCKET="$1"
S3_KEY="$2"
REGION="$3"
DESCRIPTION="$4"
LICENSE_TYPE="$5"
OUTPUT_FILE="$6"

echo "=============================================="
echo "Starting VM Import"
echo "Source: s3://${S3_BUCKET}/${S3_KEY}"
echo "Region: ${REGION}"
echo "=============================================="

IMPORT_TASK_ID=$(aws ec2 import-image \
  --region "${REGION}" \
  --description "${DESCRIPTION}" \
  --license-type "${LICENSE_TYPE}" \
  --disk-containers "Description=VM Import,Format=ova,UserBucket={S3Bucket=${S3_BUCKET},S3Key=${S3_KEY}}" \
  --query 'ImportTaskId' \
  --output text)

echo "Import task: $IMPORT_TASK_ID"
echo ""

while true; do
  STATUS=$(aws ec2 describe-import-image-tasks \
    --region "${REGION}" \
    --import-task-ids "$IMPORT_TASK_ID" \
    --query 'ImportImageTasks[0].[Status,StatusMessage,Progress]' \
    --output text)

  STATE=$(echo "$STATUS" | awk '{print $1}')
  MESSAGE=$(echo "$STATUS" | awk '{$1=""; $NF=""; print}' | xargs)
  PROGRESS=$(echo "$STATUS" | awk '{print $NF}')

  echo "$(date '+%H:%M:%S') | $STATE | $PROGRESS% | $MESSAGE"

  if [ "$STATE" = "completed" ]; then
    AMI_ID=$(aws ec2 describe-import-image-tasks \
      --region "${REGION}" \
      --import-task-ids "$IMPORT_TASK_ID" \
      --query 'ImportImageTasks[0].ImageId' \
      --output text)

    echo ""
    echo "Import complete! AMI: $AMI_ID"
    echo -n "$AMI_ID" > "${OUTPUT_FILE}"
    break
  fi

  if [ "$STATE" = "deleted" ] || [ "$STATE" = "failed" ]; then
    echo "ERROR: Import failed!"
    aws ec2 describe-import-image-tasks \
      --region "${REGION}" \
      --import-task-ids "$IMPORT_TASK_ID"
    exit 1
  fi

  sleep 30
done