include ../../env

version=0.1.0
function_name1=bundle-sync
function_name2=bundle-content
bundle=lambda-bundle-sync-$(version).zip

js=./js/bundle-sync.js
ts=./src/bundle-sync.ts

lambda: $(bundle)

%.js: $(ts) ./tsconfig.json
	npm run compile

node_modules: package.json
	npm ci

%.zip: ./node_modules $(js) ./dist
	cd dist && 	zip -r ../$(bundle) js node_modules && cd ..
	@echo "files list:"
	@unzip -t $(bundle) |  grep -v node_modules

dist: $(js)
	./node_modules/.bin/copy-node-modules . dist
	#mkdir dist/node_modules/accounts-github
	#cp ../../lib/github/index.* dist/node_modules/accounts-github
	cp -rv js dist

upload: $(bundle)
	aws s3 --profile $(aws_profile) cp $(bundle) s3://$(bucket)

release: lint upload
	aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name1) --s3-bucket $(bucket) --s3-key $(bundle) --publish
	aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name2) --s3-bucket $(bucket) --s3-key $(bundle) --publish

#	$(eval  VERSION := $(shell aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name1) --s3-bucket $(bucket) --s3-key $(bundle) --publish | jq -r .Version))
#	aws lambda --profile $(aws_profile) update-alias --function-name $(function_name1) --function-version $(VERSION) --name PROD 1>/dev/null
#	$(eval  VERSION := $(shell aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name2) --s3-bucket $(bucket) --s3-key $(bundle) --publish | jq -r .Version))
#	aws lambda --profile $(aws_profile) update-alias --function-name $(function_name2) --function-version $(VERSION) --name PROD 1>/dev/null

delete-old-versions:
	$(eval  VERSION := $(shell aws lambda --profile $(aws_profile) publish-version --function-name $(function_name) | jq -r .Version))
	for v in $(shell seq 1 $(VERSION)); do \
		echo delete version: $${v}; \
		aws lambda --profile $(aws_profile) delete-function --function-name $(function_name) --qualifier $${v}; \
	done

lint:
	./node_modules/.bin/tslint --project .

local: $(js)
	lambda-local -l js/index.js -h handler -e events/event-post-token.json

log1:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name1)

log2:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name2)

clean:
	rm -f $(bundle)
	rm -rf js dist

.PHONY: clean log release lint



