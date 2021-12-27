api_id=bqj1xq2eed
outfile=repository.json
output_folder='../../client-java'

#target: repository.yaml
target: repository.json

%.yaml:
	aws apigateway --profile opc get-export --rest-api-id $(api_id) --stage-name stg --export-type oas30 --parameters extensions='authorizers' --accepts 'application/yaml' $@
	gsed -e 's/+}:/}:/' -i $@

%.json:
	aws apigateway --profile opc get-export --rest-api-id $(api_id) --stage-name stg --export-type oas30 --parameters extensions='authorizers' --accepts 'application/json' $@
	gsed -e 's/+}" :/}" :/' -i $@

clean:
	rm -f $(outfile)

java: repository.yaml
	rm -rf "$(output_folder)/src/"

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

	pushd ${output_folder} && gsed -e 's|<jackson-threetenbp-version>2.9.10</jackson-threetenbp-version>|<jackson-threetenbp-version>2.6.4</jackson-threetenbp-version>|' -i pom.xml && mvn compile && popd

reexport:
	make clean
	make

lint: repository.json
	openapi lint  $< --skip-rule operation-operationId

preview: repository.json
	openapi preview-docs -p 8888 repository.json

.PHONEY: clean
