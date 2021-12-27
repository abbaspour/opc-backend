#!/usr/local/bin/bash

declare -r AWS_PROFILE='opc'

set -eo pipefail

declare -r running_task_ids=$(aws ecs --profile ${AWS_PROFILE} list-tasks --cluster opa-ecs-cluster | jq -r .taskArns[])

for tid in ${running_task_ids}; do
  aws ecs --profile ${AWS_PROFILE} describe-tasks --cluster opa-ecs-cluster --tasks "${tid}" | jq -r .tasks[].containers[].name
done
