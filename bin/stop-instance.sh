#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-v|-h]
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit ${1}
}

while getopts "hv?" opt
do
    case ${opt} in
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. "; usage 1; }
readonly exp=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -d -w0 2>/dev/null | jq -r '.exp')
readonly now=$(date +%s)
[[ ${exp} -le ${now} ]] && { echo >&2 "ERROR: access_token expired."; exit 3; }

# shellcheck disable=SC2154
curl -s -X POST -H "Authorization: Bearer ${access_token}" https://api.openpolicy.cloud/runtime/v1/instances/stop

echo
