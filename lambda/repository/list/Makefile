include ../../env

version=0.1.0
lambda_name=list-repo
function_name_bundles=list-bundles
function_name_policies=list-policies
bundle=lambda-$(lambda_name)-$(version).zip

lambda: $(bundle)

js=./dist/list/app.js
ts=./src/list.ts

%.js: $(ts) tsconfig.json
	npm run build

lambda-$(lambda_name)-$(version).zip: $(js)
	rm -f $@
	cd dist && zip -Xr ../$@ . -x *.LICENSE.txt

.%-uploaded: $(bundle)
	aws s3 --profile $(aws_profile) cp $< s3://$(bucket)
	touch $@

upload: .$(bundle)-uploaded

.%-released: .%-uploaded
	aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name_bundles) --s3-bucket $(bucket) --s3-key $(bundle) --publish 1>/dev/null
	aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name_policies) --s3-bucket $(bucket) --s3-key $(bundle) --publish 1>/dev/null
	touch $@

release: .$(bundle)-released

log:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name_policies)

clean:
	rm -f lambda-$(lambda_name)-*.zip
	rm -rf dist
	rm -f .*-uploaded
	rm -f .*-released

.PHONY: clean log
