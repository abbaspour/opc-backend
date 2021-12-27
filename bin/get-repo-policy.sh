#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -f file     # file name to download
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f policy.rego
END
    exit ${1}
}

declare file=''

[[ -f ".env" ]] && source .env

while getopts "e:f:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        f) file="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${file}" ]] && { echo >&2 "ERROR: file undefined. "; usage 1; }

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. "; usage 1; }
readonly exp=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -d -w0 2>/dev/null | jq -r '.exp')
readonly now=$(date +%s)
[[ ${exp} -le ${now} ]] && { echo >&2 "ERROR: access_token expired."; exit 3; }

# shellcheck disable=SC2154
wget --header="authorization: Bearer ${access_token}" "https://api.openpolicy.cloud/repository/v1/policies/${file}" -O "${file}"
