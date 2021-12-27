#!/usr/bin/env bash

declare -r bundle_version='0.1.0'
declare -r bundle="lambda-bundle-sync-${bundle_version}.zip"
declare -r function_name='bundle-sync'
declare -r AWS_PROFILE='opc'
declare -r bucket=opal-lambda-dev


# Preparing and deploying Function to Lambda
make clean
npm i
make upload

#aws lambda --profile ${AWS_PROFILE} update-function-code --function-name ${function_name} --zip-file fileb://${bundle}
aws lambda --profile ${AWS_PROFILE} update-function-code --function-name ${function_name} --s3-bucket ${bucket} --s3-key ${bundle}

# Publishing a new Version of the Lambda function
version=$(aws lambda --profile ${AWS_PROFILE} publish-version --function-name ${function_name} | jq -r .Version)

# Updating the PROD Lambda Alias so it points to the new function
aws lambda --profile ${AWS_PROFILE} update-alias --function-name ${function_name} --function-version "${version}" --name PROD 1>/dev/null

aws lambda --profile ${AWS_PROFILE} get-function --function-name "${function_name}" 1>/dev/null
