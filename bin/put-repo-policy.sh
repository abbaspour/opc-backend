#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -p package  # package path (default is auto detect)
        -f file     # file name to download
        -h|?        # usage
        -v          # verbose

eg,
     $0 -p my.test -f policy.rego
END
    exit ${1}
}

declare file=''
declare package=''

#[[ -f ".env" ]] && source .env

while getopts "e:f:p:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        f) file="${OPTARG}";;
        p) package="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${file}" ]] && { echo >&2 "ERROR: file undefined. "; usage 1; }
[[ -z "${package}" ]] && package=$(awk '/^package/{print $2}' "${file}" | head )

package=$( echo "${package}" | tr '.' '/')
[[ ${package} =~ "/$" ]] || package+='/'

readonly basename=$(basename "${file}")

# shellcheck disable=SC2154
curl  -H "Authorization: Bearer ${access_token}" "https://api.openpolicy.cloud/repository/v1/policies/${package}${basename}" --upload-file "${file}"

echo
