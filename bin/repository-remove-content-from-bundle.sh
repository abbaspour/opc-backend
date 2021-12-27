#!/bin/bash

set -eo pipefail

readonly DEFAULT_BUNDLE='bundle.tar.gz'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-c content] [-v|-h]
        -e file     # .env file location (default cwd)
        -b bundle   # bundle name. defaults to $DEFAULT_BUNDLE
        -c content  # policy or data file name
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f bundle.tar.gz
END
    exit ${1}
}

declare bundle=${DEFAULT_BUNDLE}
declare content=''

while getopts "e:b:c:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        b) bundle="${OPTARG}";;
        c) content="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${bundle}" ]] && { echo >&2 "ERROR: bundle undefined. "; usage 1; }
[[ -z "${content}" ]] && { echo >&2 "ERROR: content undefined. "; usage 1; }

# shellcheck disable=SC2154
curl -X DELETE -H "Authorization: Bearer ${access_token}" "https://api.openpolicy.cloud/repository/v1/bundles/${bundle}/contents/${content}"

echo
