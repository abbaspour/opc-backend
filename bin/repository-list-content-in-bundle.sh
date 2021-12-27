#!/bin/bash

set -eo pipefail

readonly DEFAULT_BUNDLE='bundle.tar.gz'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-b bundle] [-v|-h]
        -e file     # .env file location (default cwd)
        -b bundle   # bundle name. defaults to $DEFAULT_BUNDLE
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f bundle.tar.gz
END
    exit ${1}
}

declare bundle=${DEFAULT_BUNDLE}
declare content=''

while getopts "e:b:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        b) bundle="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${bundle}" ]] && { echo >&2 "ERROR: bundle undefined. "; usage 1; }

# shellcheck disable=SC2154
curl -X GET -H "Authorization: Bearer ${access_token}" "https://api.openpolicy.cloud/repository/v1/bundles/${bundle}/contents"

echo
