#!/usr/bin/env bash

aws apigateway --profile opc get-export --rest-api-id  bqj1xq2eed --stage-name stg --export-type oas30 --parameters extensions='authorizers' --accepts 'application/yaml' repository.yaml
gsed -e 's/+}:/}:/' -i repository.yaml
# gsed -e 's/+}" :/}" :/' -i repository.json
