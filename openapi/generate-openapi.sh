openapi-generator generate -i repository.yml \
  --api-package cloud.openpolicy.client.api \
  --model-package cloud.openpolicy.client.model \
  --invoker-package cloud.openpolicy.client.invoker \
  --group-id cloud.openpolicy \
  --artifact-id spring-openapi-generator-api-client \
  --artifact-version 0.0.1-SNAPSHOT \
  -g java \
  -p java8=true \
  --library resttemplate \
  -o ../../client-java/ \
  --skip-validate-spec
