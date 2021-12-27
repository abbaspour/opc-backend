#!/usr/local/bin/bash

declare -r AWS_PROFILE='opc'
declare -r TEST_ACCOUNT_NO=100368421
#declare -r DB_INSTANCE='terraform-20201105040901897300000004'

## start nat/jump instance
aws ec2 --profile ${AWS_PROFILE} start-instances --instance-ids $(aws ec2 --profile ${AWS_PROFILE} describe-instances --filters "Name=tag:Name,Values=nat" | jq -r '.Reservations[].Instances[].InstanceId')


## start ssh & test account opa task
./start-task.sh -n ssh
./start-task.sh -a ${TEST_ACCOUNT_NO}

## start RDS
#aws rds --profile ${AWS_PROFILE} start-db-instance --db-instance-identifier ${DB_INSTANCE}
