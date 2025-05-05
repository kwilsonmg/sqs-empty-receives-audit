#!/usr/bin/env bash

set -e

# Check for dependencies
command -v aws >/dev/null 2>&1 || { echo >&2 "aws CLI is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed."; exit 1; }

usage() {
    echo "Usage: $0 [-r region] [-d days] [-p profile]"
    echo
    echo "Options:"
    echo "  -r region     AWS region (default: us-west-2)"
    echo "  -d days       Number of days to look back (default: 1)"
    echo "  -p profile    AWS named profile to use"
    echo "  -h            Show this help message"
    exit 1
}

# Default values
REGION="us-west-2"
DAYS_BACK=1
PROFILE=""

# Parse options
while getopts ":r:d:p:h" opt; do
  case $opt in
    r) REGION="$OPTARG" ;;
    d) DAYS_BACK="$OPTARG" ;;
    p) PROFILE="--profile $OPTARG" ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Generate start and end timestamps in ISO 8601 format
START_TIME=$(python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) - timedelta(days=$DAYS_BACK)).isoformat())")
END_TIME=$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())')

QUEUE_URLS=$(aws sqs list-queues --region "$REGION" $PROFILE --query 'QueueUrls' --output text)

if [[ -z "$QUEUE_URLS" ]]; then
    echo "No SQS queues found in region $REGION."
    exit 0
fi

QUEUE_NAMES=()
QUEUE_TOTALS=()

echo "Checking SQS queues in region '$REGION' from $START_TIME to $END_TIME..."
echo

# Set period based on range
if [ "$DAYS_BACK" -le 1 ]; then
  PERIOD=300
elif [ "$DAYS_BACK" -le 7 ]; then
  PERIOD=900
elif [ "$DAYS_BACK" -le 30 ]; then
  PERIOD=3600
else
  PERIOD=86400
fi

for QUEUE_URL in $QUEUE_URLS; do
    QUEUE_NAME=$(basename "$QUEUE_URL")
    METRIC_DATA=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/SQS \
        --metric-name NumberOfEmptyReceives \
        --dimensions Name=QueueName,Value="$QUEUE_NAME" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period $PERIOD \
        --statistics Sum \
        --region "$REGION" $PROFILE \
        --output json)

    DATA_POINTS=$(echo "$METRIC_DATA" | jq '.Datapoints')
    COUNT=$(echo "$DATA_POINTS" | jq 'length')

    if [[ "$COUNT" -gt 0 ]]; then
        TOTAL=$(echo "$DATA_POINTS" | jq '[.[].Sum] | add')
        echo "Queue: $QUEUE_NAME"
        echo "  Total Empty Receives: $TOTAL"
        echo "----------------------------------------"
        QUEUE_NAMES+=("$QUEUE_NAME")
        QUEUE_TOTALS+=("$TOTAL")
    fi
done

echo "Using CloudWatch period of $PERIOD seconds"

echo
echo "CSV Summary:"
echo "QueueName,TotalEmptyReceives"
for i in "${!QUEUE_NAMES[@]}"; do
    echo "${QUEUE_NAMES[$i]},${QUEUE_TOTALS[$i]}"
done
