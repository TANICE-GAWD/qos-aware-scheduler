#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export AWS_PROFILE=ucs531-qos
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1

SEED_ARN=$(aws cloudformation describe-stacks --stack-name ucs531-qos-hosted-data --query "Stacks[0].Outputs[?OutputKey=='RuntimeSeedArn'].OutputValue | [0]" --output text)
SEED=$(aws secretsmanager get-secret-value --secret-id "$SEED_ARN" --query SecretString --output text)
URL=$(aws cloudformation describe-stacks --stack-name ucs531-qos-hosted-gateway --query "Stacks[0].Outputs[?OutputKey=='DashboardUrl'].OutputValue | [0]" --output text)
IMAGE=$(aws cloudformation describe-stacks --stack-name ucs531-qos-resources --query "Stacks[0].Outputs[?OutputKey=='ImageRepository'].OutputValue | [0]" --output text)
DIGEST=$(aws cloudformation describe-stacks --stack-name ucs531-qos-hosted-app --query "Stacks[0].Parameters[?ParameterKey=='WorkerImageDigest'].ParameterValue | [0]" --output text)

case "$URL" in
  https://*) ;;
  *) echo "Could not read the dashboard URL." >&2; exit 1 ;;
esac
case "$DIGEST" in
  sha256:*) ;;
  *) echo "Could not read the worker image digest." >&2; exit 1 ;;
esac

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${IMAGE%%/*}"
{
  echo "WORKER_API_URL=$URL"
  echo "WORKER_IMAGE_REF=${IMAGE}@${DIGEST}"
  printf '%s' "$SEED" | node --import tsx scripts/hosted-secrets.ts workers
} > .env.aws-workers
printf '%s' "$SEED" | node --import tsx scripts/hosted-secrets.ts operator | wl-copy
unset SEED
echo "Workers file written. Operator token copied."
