include ../../env

version=0.1.3
function_name=create-account
bundle=lambda-$(function_name)-$(version).zip

lambda: $(bundle)

%.js: ./src/create-account.ts ./tsconfig.json
	npm run compile

node_modules: package.json
	npm ci

lambda-$(function_name)-$(version).zip: ./node_modules ./js/create-account.js ./dist
	cd dist && 	zip -r ../$(bundle) js node_modules && cd ..
	@echo "files list:"
	@unzip -t $(bundle) |  grep -v node_modules

dist: ./js/create-account.js
	./node_modules/.bin/copy-node-modules . dist
	mkdir dist/node_modules/accounts-github
	cp ../../lib/github/index.* dist/node_modules/accounts-github
	cp -rv js dist

upload: $(bundle)
	aws s3 --profile $(aws_profile) cp $(bundle) s3://$(bucket)

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

local: ./js/create-account.js
	lambda-local -l js/index.js -h handler -e events/event-post-token.json

log:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name)

clean:
	rm -f lambda-$(function_name)-*.zip
	rm -rf js dist

.PHONY: clean log release lint
