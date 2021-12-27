
version=0.1.4
bucket=opal-lambda-dev
bundle=lambda-update-policy-$(version).zip
aws_profile=opc

lambda: $(bundle)

%.zip: src package.json node_modules
	zip -r $(bundle) src node_modules
	@echo "files list:"
	unzip -t $(bundle) |  grep -v node_modules

node_modules:
	npm i

upload: $(bundle)
	aws s3 --profile $(aws_profile) cp $(bundle) s3://$(bucket)

log:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/update-policy

clean:
	rm lambda-*.zip

.PHONY: clean
