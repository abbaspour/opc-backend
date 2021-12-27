include ../env

version=0.1.0
function_name=post-token
bundle=lambda-$(function_name)-$(version).zip

lambda: $(bundle)

%.js: ./src/index.ts ./tsconfig.json
	npm run compile

node_modules: package.json
	npm ci

lambda-$(function_name)-$(version).zip: ./node_modules ./js/index.js ./dist
	cd dist && 	zip -qr ../$(bundle) js node_modules && cd ..
	@echo "files list:"
	@unzip -t $(bundle) |  grep -v node_modules

dist: ./js/index.js
	./node_modules/.bin/copy-node-modules . dist
	cp -rv js dist

upload: $(bundle)
	aws s3 --profile $(aws_profile) cp $(bundle) s3://$(bucket)

release: lint upload
	aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name) --s3-bucket $(bucket) --s3-key $(bundle) --publish
	$(eval  VERSION := $(shell aws lambda --profile $(aws_profile) publish-version --function-name $(function_name) | jq -r .Version))
	@echo "New version: ${VERSION}"
	aws lambda --profile $(aws_profile) update-alias --function-name $(function_name) --function-version '$$LATEST' --name PROD 1>/dev/null
	#aws lambda --profile $(aws_profile) get-function --function-name $(function_name) 1>/dev/null

lint:
	./node_modules/.bin/tslint --project .

local: ./js/index.js
	lambda-local -l js/index.js -h handler -e events/event-post-token.json

log:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name)

clean:
	rm -f lambda-$(function_name)-*.zip
	rm -rf js dist

.PHONY: clean log release lint
