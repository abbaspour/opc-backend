#!/usr/local/bin/bash

declare -r AWS_PROFILE='opc'
#declare -r DB_INSTANCE='terraform-20201105040901897300000004'

## stop nat/jump instance
aws ec2 --profile ${AWS_PROFILE} stop-instances --instance-ids $(aws ec2 --profile ${AWS_PROFILE} describe-instances --filters "Name=tag:Name,Values=nat" | jq -r '.Reservations[].Instances[].InstanceId')

./stop-task.sh -n ssh

declare account_no

for name in $(./list-tasks.sh | grep opa-task); do
  account_no=$(echo "${name}" | awk -F- '{print $NF}')
  ./stop-task.sh -a "${account_no}"
done

# aws rds --profile ${AWS_PROFILE} stop-db-instance --db-instance-identifier ${DB_INSTANCE}
