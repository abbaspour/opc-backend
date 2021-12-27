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
#readonly client_id='phi6Ainootex'
#readonly client_secret='IeGahfim2di4'

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

#export HTTP_PROXY='http://localhost:8888'
#export HTTPS_PROXY='http://localhost:8888'
#export http_proxy='http://localhost:8888'
#export https_proxy='http://localhost:8888'

readonly url='https://api.openpolicy.cloud/repository/v1/bundles'
readonly token_url='https://api.openpolicy.cloud/runtime/token'

opa run -s -a :1080 -l debug \
 --set "services.gw.url=${url}" \
 --set "services.gw.credentials.oauth2.grant_type=client_credentials" \
 --set "services.gw.credentials.oauth2.token_url=${token_url}" \
 --set "services.gw.credentials.oauth2.client_id=${client_id}" \
 --set "services.gw.credentials.oauth2.client_secret=${client_secret}" \
 --set "services.gw.allow_insecure_tls=true" \
 --set "bundles.root.service=gw" \
 --set "bundles.root.resource=/bundle.tar.gz" \
 --set "bundles.root.persist=false" \
 --set "bundles.root.polling.min_delay_seconds=600" \
 --set "bundles.root.polling.max_delay_seconds=1200" \
 --set "status.console=true" \
 --set "decision_logs.console=true"
