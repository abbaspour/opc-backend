#!/usr/local/bin/bash

set -eo pipefail

declare -r AWS_PROFILE='opc'
declare -r BASTION_HOST=jump.openpolicy.cloud
declare -r BASTION_USER=ec2-user
declare -r RDS=terraform-20201105040901897300000004.cwmfl1qcfwny.ap-southeast-2.rds.amazonaws.com

function usage() {
    cat <<END >&2
USAGE: $0 [-d|-s]
        -d            # tunnel db
        -s            # tunnel ecs ssh
        -h|?          # usage
        -v            # verbose

eg,
     $0 -d
END
    exit ${1}
}

declare TUNNEL=''

while getopts "dshv?" opt
do
    case ${opt} in
        d) TUNNEL="-L 0.0.0.0:13306:${RDS}:3306";;
        s) task=$(aws ecs --profile ${AWS_PROFILE} list-tasks --cluster opa-ecs-cluster --service-name ssh | jq -r '.taskArns[0]')
           ip=$(aws ecs --profile ${AWS_PROFILE} describe-tasks --cluster opa-ecs-cluster --tasks "${task}" | jq -r '.tasks[0].containers[0].networkInterfaces[0].privateIpv4Address');
           TUNNEL="-L 0.0.0.0:2223:${ip}:2222";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done


ssh ${TUNNEL} ${BASTION_USER}@${BASTION_HOST}
