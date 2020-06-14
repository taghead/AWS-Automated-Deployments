db-test-up:
	cd infra && ENV=test make init
	cd infra && ENV=test make up

db-prod-up:
	cd infra && ENV=prod make init
	cd infra && ENV=prod make up

environment-up: 
	cd environment && make up
	cd environment && make kube-up
	sed -i "/--state s3:\/\/rmit-kops-state-/c\          kops export kubecfg rmit.k8s.local --state s3:\/\/rmit-kops-state-$(shell  cd ./environment/infra && terraform output state_bucket_name | cut -d "-" -f 3 )" .circleci/config.yml
	sed -i "/ECR:/c\      ECR: $(shell  cd ./environment/infra && terraform output ecr_url | cut -d "/" -f 1 )" .circleci/config.yml
	sed -i "/--backend-config/c\	terraform init --backend-config=\"key=state/"$$"{ENV}.tfstate\" --backend-config=\"dynamodb_table=RMIT-locktable-$(shell  cd ./environment/infra && terraform output state_bucket_name | cut -d "-" -f 3 )\" --backend-config=\"bucket=rmit-tfstate-$(shell  cd ./environment/infra && terraform output state_bucket_name | cut -d "-" -f 3 )\"" infra/Makefile
	sed -i "/vpc_id/c\vpc_id = \"$(shell aws ec2 describe-vpcs --filter Name=tag:Name,Values=rmit.k8s.local --query Vpcs[].VpcId --output text)\"" infra/terraform.tfvars
	sed -i "/subnet_ids/c\subnet_ids = [ \"$(shell aws ec2 describe-subnets --filter Name=tag:Name,Values=us-east-1a.rmit.k8s.local --query Subnets[].SubnetId --output text)\", \"$(shell aws ec2 describe-subnets --filter Name=tag:Name,Values=us-east-1b.rmit.k8s.local --query Subnets[].SubnetId --output text)\" ]" infra/terraform.tfvars
	

all-down:
	helm uninstall acme -n prod
	kubectl delete namespace prod
	helm uninstall acme -n test
	kubectl delete namespace test
	
	cd infra && ENV=prod make down
	cd infra && ENV=test make down

	cd environment && make kube-down
	cd environment && make down