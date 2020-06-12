stand-up:
	cd environment && make up
	cd environment && make kube-up

	cd infra && make init
	cd infra && make up