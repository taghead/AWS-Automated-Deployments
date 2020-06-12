stand-up:
	cd environment && make up
	cd environment && make kube-up

	cd infra && ENV=test make init
	cd infra && ENV=test make up