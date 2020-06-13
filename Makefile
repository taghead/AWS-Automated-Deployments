env-up:
	cd environment && make up
	cd environment && make kube-up

env-down:
	cd environment && make down
	cd environment && make kube-down


db-test-up:
	cd infra && ENV=test make init
	cd infra && ENV=test make up

db-test-down:
	cd infra && ENV=test make down


db-prod-up:
	cd infra && ENV=prod make init
	cd infra && ENV=prod make up

db-prod-down:
	cd infra && ENV=prod make down

all-up:
	make env-up
	make db-prod-up
	make db-test-up

all-down:
	make db-test-down
	make db-prod-down
	make env-down