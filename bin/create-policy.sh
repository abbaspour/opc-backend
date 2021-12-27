#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-b url] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -b url      # base url
        -f file     # policy payload file
        -n name     # policy name
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f policy.rego -n example2
END
    exit ${1}
}

declare OPA_ENDPOINT=''
declare PAYLOAD=''
declare NAME=''

[[ -f ".env" ]] && source .env

while getopts "e:b:f:n:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        b) OPA_ENDPOINT="${OPTARG}";;
        f) PAYLOAD="${OPTARG}";;
        n) NAME=$(echo "${OPTARG}" | tr '.' '/');;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${ENDPOINT}" ]] && { echo >&2 "ERROR: ENDPOINT undefined. "; usage 1; }
[[ -z "${OPA_ENDPOINT}" ]] && { echo >&2 "ERROR: OPA_ENDPOINT undefined. "; usage 1; }
[[ -z "${NAME}" ]] && { echo >&2 "ERROR: NAME undefined. "; usage 1; }

curl -s -X PUT -H "Authorization: Bearer ${access_token}" --data-binary @"${PAYLOAD}" --url "${OPA_ENDPOINT}/v1/policies/${NAME}" | jq .
