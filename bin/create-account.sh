#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-b url] [-u user_id] [-v|-h]
        -e file      # .env file location (default cwd)
        -b url       # base url
        -u user_id   # admin user_id
        -h|?         # usage
        -v           # verbose

eg,
     $0
END
    exit ${1}
}

declare ENDPOINT=''
declare user_id=''

[[ -f ".env" ]] && source .env

while getopts "e:b:f:p:u:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        b) ENDPOINT="${OPTARG}";;
        u) user_id="${OPTARG}";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined. "; usage 1; }

declare BODY=$(cat <<EOL
{
  "user_id":"${user_id}"
}
EOL
)
[[ -z "${ENDPOINT}" ]] && { echo >&2 "ERROR: ENDPOINT undefined. "; usage 1; }

curl -s -X POST -H "Authorization: Bearer ${admin_access_token}" \
  --header 'content-type: application/json' \
  -d "${BODY}" --url "${ENDPOINT}/runtime/v1/account" | jq .
