.PHONY: help init validate plan apply destroy

help:
	@echo "AWS ECS Microservices — Terraform Commands"
	@echo "==========================================="
	@echo ""
	@echo "  make init       Initialize Terraform and download providers"
	@echo "  make validate   Format check and validate HCL"
	@echo "  make plan       Show execution plan (dry-run)"
	@echo "  make apply      Provision all AWS resources"
	@echo "  make destroy    Tear down all AWS resources"

init:
	cd terraform && terraform init

validate:
	cd terraform && terraform fmt -check -recursive && terraform validate

plan:
	cd terraform && terraform plan -out=tfplan

apply:
	cd terraform && terraform apply tfplan

destroy:
	cd terraform && terraform destroy
