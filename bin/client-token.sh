#!/usr/bin/env bash

set -ueo pipefail

readonly profile='opc'

declare account_no=''

function usage() {
    cat <<END >&2
USAGE: $0 [-a account_no] [-v|-h]
        -a account_no  # account_no
        -h|?           # usage
        -v             # verbose

eg,
     $0 -a 100368421
END
    exit $1
}

#account_no=100368421

while getopts "a:hv?" opt
do
    case ${opt} in
        a) account_no=${OPTARG};;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${account_no}" ]] && { echo >&2 "ERROR: account_no undefined"; usage 1; }


readonly entry=$(aws dynamodb --profile ${profile} scan \
  --table-name api_client \
  --filter-expression "account_no = :account_no" \
 --expression-attribute-values "{\":account_no\":{\"N\":\"${account_no}\"}}")


readonly client_id=$(echo "$entry" | jq | jq -r '.Items[0].client_id.S')
readonly client_secret=$(echo "$entry" | jq | jq -r '.Items[0].client_secret.S')

./get-token.sh -u "${client_id}" -p "${client_secret}"
