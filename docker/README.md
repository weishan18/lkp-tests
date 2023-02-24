# Docker Support

This is initial support of docker, which is not like typical docker image because
all environment setup is wrapped in lkp install instead of Dockerfile.

The main limitation is the installed dependencies of test are not persistent. User may
consider to create image for interested test for easy reuse.

## Getting started

```
	git clone https://github.com/intel/lkp-tests.git

	cd lkp-tests

	image=debian/buster
	docker build -f docker/${image}/Dockerfile -t lkp-tests/${image}:latest -t lkp-tests/${image}:$(git log -1 --pretty=%h) --build-arg hostname=lkp-docker .

	docker run --rm lkp-tests/${image} lkp help
```

## Run one atomic job

```
	# Add --privileged option to allow privileged access like dmesg, sysctl. Use
	# this with caution.
	docker run -d -h lkp-docker --name lkp-docker \
	           -v /home/$USER/lkp/paths:/lkp/paths \
	           -v /home/$USER/lkp/benchmarks:/lkp/benchmarks \
	           -v /home/$USER/lkp/result:/lkp/result \
	           -v /home/$USER/lkp/jobs:/lkp/jobs \
	           lkp-tests/${image}

	docker exec -it lkp-docker bash

	/lkp/lkp-tests# lkp split-job jobs/hackbench.yaml -o /lkp/jobs

	# Install the dependencies for the splited job and generate binary at /lkp/benchmarks
	# Pls note all dependencies are inside container and not persistent.
	/lkp/lkp-tests# lkp install /lkp/jobs/hackbench-pipe-8-process-1600%.yaml

	# The jobs and benchmarks are persistent, thus this can be run directly in a new
	# container. It does not work for all tests, so that lkp install need rerun.
	/lkp/lkp-tests# lkp run /lkp/jobs/hackbench-pipe-8-process-1600%.yaml

	/lkp/lkp-tests# lkp rt hackbench
```
