#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -f file     # file name to delete
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f bundle.tar.gz
END
    exit ${1}
}

declare bundle=''

#[[ -f ".env" ]] && source .env

while getopts "e:f:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        f) bundle="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${bundle}" ]] && { echo >&2 "ERROR: bundle undefined. "; usage 1; }

# shellcheck disable=SC2154
curl -X DELETE -H "Authorization: Bearer ${access_token}" "https://api.openpolicy.cloud/repository/v1/bundles/${bundle}"
