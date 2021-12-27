#!/bin/bash

set -ueo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

command -v jq > /dev/null || { echo >&2 "jq not installed"; exit 1; }

function usage() {
    cat <<END >&2
USAGE: $0 [-u client_id] [-p client_secret] [-m|-v|-h]
        -u username    # opc username
        -p password    # opc password
        -h|?           # usage
        -v             # verbose

eg,
     $0 -u xxx -p yyy
END
    exit $1
}

declare username=''
declare password=''

[[ -f ".env" ]] && source .env

while getopts "e:u:p:hv?" opt
do
    case ${opt} in
        u) username=${OPTARG};;
        p) password=${OPTARG};;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${username}" ]] && { echo >&2 "ERROR: username undefined"; usage 1; }
[[ -z "${password}" ]] && { echo >&2 "ERROR: password undefined"; usage 1; }

readonly basic=$(echo -n "${username}:${password}" | openssl base64 )

readonly access_token=$(curl -s -k -H "authorization: Basic ${basic}" -d "grant_type=client_credentials" "${ENDPOINT}/runtime/token" | jq -r '.access_token')
echo "export access_token='${access_token}'"

