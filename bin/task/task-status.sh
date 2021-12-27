#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-a account_no] [-n name]
        -a account_no # account_no
        -n name       # service name
        -h|?          # usage
        -v            # verbose

eg,
     $0 -a 100368421
END
    exit ${1}
}


declare -r AWS_PROFILE='opc'
declare -r ECS_CLUSTER='opa-ecs-cluster'

declare ECS_SERVICE=''

while getopts "a:n:hv?" opt
do
    case ${opt} in
        a) ECS_SERVICE="opa-${OPTARG}";;
        n) ECS_SERVICE="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${ECS_SERVICE}" ]] && { echo >&2 "ERROR: ECS_SERVICE undefined. "; usage 1; }

aws ecs --profile ${AWS_PROFILE} describe-services --cluster ${ECS_CLUSTER} --services "${ECS_SERVICE}" | jq '.services[0].deployments[0]'

