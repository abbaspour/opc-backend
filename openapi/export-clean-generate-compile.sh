#!/usr/bin/env bash

readonly api_id='bqj1xq2eed'
readonly output_folder='../../client-java'

aws apigateway --profile opc get-export --rest-api-id  ${api_id} --stage-name stg --export-type oas30 --parameters extensions='authorizers' --accepts 'application/yaml' repository.yaml
gsed -e 's/+}:/}:/' -i repository.yaml

rm -rf "${output_folder}/src/"

swagger-codegen generate -i repository.yaml \
  --api-package cloud.openpolicy.client.api \
  --model-package cloud.openpolicy.client.model \
  --invoker-package cloud.openpolicy.client.invoker \
  --group-id cloud.openpolicy \
  --artifact-id spring-openapi-generator-api-client \
  --artifact-version 0.0.1-SNAPSHOT \
  -l java \
  -Djava8=true \
  --library resttemplate \
  -o ${output_folder}
  #--skip-validate-spec

pushd ${output_folder} || exit

gsed -e 's|<jackson-threetenbp-version>2.9.10</jackson-threetenbp-version>|<jackson-threetenbp-version>2.6.4</jackson-threetenbp-version>|' -i pom.xml

mvn compile

popd || exit
