rm -rf ../../client-java/src

# swagger-codegen config-help -l java

swagger-codegen generate -i repository.json \
  --api-package cloud.openpolicy.client.api \
  --model-package cloud.openpolicy.client.model \
  --invoker-package cloud.openpolicy.client.invoker \
  --group-id cloud.openpolicy \
  --artifact-id spring-openapi-generator-api-client \
  --artifact-version 0.0.1-SNAPSHOT \
  -l java \
  --library resttemplate \
  -o ../../client-java/
  #--skip-validate-spec
