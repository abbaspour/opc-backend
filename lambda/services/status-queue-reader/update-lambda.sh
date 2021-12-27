#!/usr/bin/env bash

declare -r bundle_version='0.1.8'
declare -r bundle="lambda-status-queue-reader-${bundle_version}.zip"
declare -r function_name='status-queue-reader'
declare -r AWS_PROFILE='opal'

# Preparing and deploying Function to Lambda
make

aws lambda --profile ${AWS_PROFILE} update-function-code --function-name ${function_name} --zip-file fileb://${bundle}

# Publishing a new Version of the Lambda function
version=$(aws lambda --profile ${AWS_PROFILE} publish-version --function-name ${function_name} | jq -r .Version)

# Updating the PROD Lambda Alias so it points to the new function
aws lambda --profile ${AWS_PROFILE} update-alias --function-name ${function_name} --function-version "${version}" --name PROD

aws lambda --profile ${AWS_PROFILE} get-function --function-name "${function_name}"
