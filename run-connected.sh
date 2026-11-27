#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export AWS_PROFILE=ucs531-qos
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export LOCAL_WORKER_CPUS=0.035
export DOCKER_CONFIG=/tmp/qos-docker
export HOSTED_VERIFY_URL=https://4k3efjo42g.execute-api.us-east-1.amazonaws.com

docker compose --env-file .env.aws-workers -f compose.workers.yaml up -d --force-recreate

seed_arn=$(aws cloudformation describe-stacks --stack-name ucs531-qos-hosted-data --query "Stacks[0].Outputs[?OutputKey=='RuntimeSeedArn'].OutputValue | [0]" --output text)
HOSTED_VERIFY_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$seed_arn" --query SecretString --output text | node --import tsx scripts/hosted-secrets.ts operator)
export HOSTED_VERIFY_TOKEN
node --import tsx scripts/verify-hosted.ts connected
unset HOSTED_VERIFY_TOKEN
python3 -c 'import json; p=json.load(open("evaluation-output/hosted/connected.json")); print("https://4k3efjo42g.execute-api.us-east-1.amazonaws.com/?job="+p["cloud"]["job"]["id"])'
