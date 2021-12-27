include ../env

version=0.1.0
function_name=jwt-authorizer
bundle=lambda-$(function_name)-$(version).zip
ts=./src/handler.ts
js=./js/handler.js

lambda: $(bundle)

%.js: $(ts) ./tsconfig.json
	npm run compile

node_modules: package.json
	npm ci

test:
	npm test

lambda-$(function_name)-$(version).zip: ./node_modules  $(js) ./dist
	@cd dist && zip -qr ../$(bundle) js node_modules && cd ..
	@echo "src files list:"
	@unzip -t $(bundle) |  grep -v node_modules

dist: ./js/index.js
	./node_modules/.bin/copy-node-modules . dist
	cp -rv js dist

upload: $(bundle)
	aws s3 --profile $(aws_profile) cp $(bundle) s3://$(bucket)
	aws s3 --profile $(aws_profile) ls s3://$(bucket)/$(bundle)

release: lint upload
	$(eval  VERSION := $(shell aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name) --s3-bucket $(bucket) --s3-key $(bundle) --publish | jq -r .Version))
	aws lambda --profile $(aws_profile) update-alias --function-name $(function_name) --function-version $(VERSION) --name PROD 1>/dev/null

delete-old-versions:
	$(eval  VERSION := $(shell aws lambda --profile $(aws_profile) publish-version --function-name $(function_name) | jq -r .Version))
	for v in $(shell seq 1 $(VERSION)); do \
		echo delete version: $${v}; \
		aws lambda --profile $(aws_profile) delete-function --function-name $(function_name) --qualifier $${v}; \
	done

lint:
	./node_modules/.bin/tslint --project .

local: ./js/index.js
	lambda-local -l $(js) -h handler -e events/event-post-v1-data.json

log:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name)

clean:
	rm -f lambda-$(function_name)-*.zip
	rm -rf js dist

.PHONY: clean log release lint test
