#!/usr/bin/env bash

source .env

declare -r OWNER='abbaspour'
declare -r REPO='opc-accounts'

curl -H "Authorization: token ${OAUTH_TOKEN}"  \
-H "Accept: application/vnd.github.v3+json" \
https://api.github.com/repos/${OWNER}/${REPO}/branches
