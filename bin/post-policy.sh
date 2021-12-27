#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-b url] [-f file] [-v|-h]
        -e file      # .env file location (default cwd)
        -b url       # base url
        -f file      # payload file
        -p package   # package path (default is sample)
        -h|?         # usage
        -v           # verbose

eg,
     $0 -f payload.json -p httpapi.authz
END
    exit ${1}
}

declare OPA_ENDPOINT=''
declare PAYLOAD=''
declare PACKAGE=''

[[ -f ".env" ]] && source .env

while getopts "e:b:f:p:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        b) OPA_ENDPOINT="${OPTARG}";;
        f) PAYLOAD="${OPTARG}";;
        p) PACKAGE=$(echo "${OPTARG}" | tr '.' '/');;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${OPA_ENDPOINT}" ]] && { echo >&2 "ERROR: ENDPOINT undefined. "; usage 1; }
#[[ -z "${PAYLOAD}" ]] && { echo >&2 "ERROR: PAYLOAD undefined. "; usage 1; }
#[[ -z "${PACKAGE}" ]] && { echo >&2 "ERROR: PACKAGE undefined. "; usage 1; }

curl -s -X POST -H "Authorization: Bearer ${access_token}" \
  -d @"${PAYLOAD}" --url "${OPA_ENDPOINT}/v1/data/${PACKAGE}" | jq .
