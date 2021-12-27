#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-b url] [-v|-h]
        -e file      # .env file location (default cwd)
        -b url       # base url
        -h|?         # usage
        -v           # verbose

eg,
     $0 -f "enable_client_connections":true
END
    exit ${1}
}

declare OPA_ENDPOINT

[[ -f ".env" ]] && source .env

while getopts "e:b:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        b) OPA_ENDPOINT="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${ENDPOINT}" ]] && { echo >&2 "ERROR: OPA_ENDPOINT undefined. "; usage 1; }

curl -s  -H "Authorization: Bearer ${access_token}" --url "${OPA_ENDPOINT}"
