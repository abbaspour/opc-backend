#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-a account_no] [-n name]
        -a account_no # account_no
        -l lambda     # lambda name
        -n name       # log group name
        -h|?          # usage
        -v            # verbose

eg,
     $0 -a 100368421
END
    exit ${1}
}

declare -r AWS_PROFILE='opc'

declare LOG_GROUP=''

while getopts "a:n:l:hv?" opt
do
    case ${opt} in
        a) LOG_GROUP="opa-${OPTARG}";;
        l) LOG_GROUP="/aws/lambda/${OPTARG}";;
        n) LOG_GROUP="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${LOG_GROUP}" ]] && { echo >&2 "ERROR: LOG_GROUP undefined. "; usage 1; }

echo "Trailing log group: ${LOG_GROUP}"
aws logs --profile ${AWS_PROFILE} tail --follow "${LOG_GROUP}"

