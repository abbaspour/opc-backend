PLAN_FILE=opc.plan

AWS_PROFILE=opc
REST_API_ID=bqj1xq2eed
LOG_LEVEL=''
LOG_PATH='./terraform.log'

REAL_HOME_IP=$(shell curl -s https://api.ipify.org)
SAVE_HOME_IP=$(shell fgrep home_ip terraform.auto.tfvars | awk '{print $$3}' | tr -d '\"')
DDNS_HOME_IP=$(shell dig +short home.abbaspour.net | tail -n1)

report="cost/infra-cost-$(shell date +%F-%H-%M-%S).txt"
rest_api_id="bqj1xq2eed"

TF=terraform

main: plan

plan:
	@echo Real home IP: $(REAL_HOME_IP)
	@echo Save home IP: $(SAVE_HOME_IP)
	@echo DDNS home IP: $(DDNS_HOME_IP)
	aws apigateway --profile $(AWS_PROFILE) update-stage --rest-api-id $(REST_API_ID) --stage-name stg --patch-operations op=replace,path=/documentationVersion,value="" 1>/dev/null
	TF_LOG=$(LOG_LEVEL) TF_LOG_PATH=$(LOG_PATH) $(TF) plan -out $(PLAN_FILE) -parallelism=20

apply:
	$(TF) apply -auto-approve $(PLAN_FILE)

show:
	$(TF) show

refresh:
	$(TF) refresh

validate:
	$(TF) validate

clean:
	rm $(PLAN_FILE)

lint:
	tflint

graph:
	$(TF) graph > graph.dot
	dot -Tsvg graph.dot -o graph.svg

cost:
	infracost --show-skipped --no-color > $(report)
	cat $(report)

deploy:
	aws apigateway --profile $(AWS_PROFILE) create-deployment --rest-api-id $(rest_api_id) --stage-name stg

.PHONY: clean plan cost
