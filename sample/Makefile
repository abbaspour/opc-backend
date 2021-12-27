aws_profile=opc
bundle_bucket=opal-policy-dev

main: discovery bundle

discovery:
	tar -zcvf discovery.tar.gz -C ./discovery data.json
	echo "content:"
	tar -ztvf discovery.tar.gz

bundle:
	tar -zcvf bundle.tar.gz -C ./bundle httpapi/
	echo "content:"
	tar -ztvf bundle.tar.gz

upload_discovery: discovery.tar.gz
	aws s3 --profile $(aws_profile) cp discovery.tar.gz s3://$(bundle_bucket)/discovery/

upload_bundle: bundle.tar.gz
	aws s3 --profile $(aws_profile) cp bundle.tar.gz s3://$(bundle_bucket)/bundle/

.PHONY: discovery bundle
