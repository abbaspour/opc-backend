#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit ${1}
}

declare -r AWS_PROFILE='opc'
declare -r ECS_CLUSTER='opa-ecs-cluster'

while getopts "hv?" opt
do
    case ${opt} in
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done



aws ecs --profile  ${AWS_PROFILE} list-services --cluster ${ECS_CLUSTER}

#aws ecs --profile ${AWS_PROFILE} update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --desired-count 1 1>/dev/null

