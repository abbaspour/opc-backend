include ../../env

version=0.1.0
function_name=start-stop-instance
bundle=lambda-$(function_name)-$(version).zip

lambda: $(bundle)

js=./dist/$(function_name)/app.js
ts=./src/$(function_name).ts

%.js: $(ts) tsconfig.json
	npm run build

lambda-$(function_name)-$(version).zip: $(js)
	rm -f $@
	cd dist && zip -Xr ../$@ . -x *.LICENSE.txt

.%-uploaded: $(bundle)
	aws s3 --profile $(aws_profile) cp $< s3://$(bucket)
	@touch $@

upload: .$(bundle)-uploaded

.%-released: .%-uploaded
	aws lambda --profile $(aws_profile) update-function-code --function-name $(function_name) --s3-bucket $(bucket) --s3-key $(bundle) --publish 1>/dev/null
	@touch $@

release: .$(bundle)-released

log:
	aws logs --profile $(aws_profile) tail --follow /aws/lambda/$(function_name)

clean:
	rm -f lambda-$(function_name)-*.zip
	rm -rf dist
	rm -f .*-uploaded
	rm -f .*-released

.PHONY: clean log

