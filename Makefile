.PHONY: all clean test

COMPOSE_RUN = docker compose run --rm --quiet-pull

export DOCKER_CLI_HINTS=false

all: clean test

clean:
	docker compose down --rmi all --remove-orphans

test: test-docker test-shellcheck nit-tests

test-docker:
	docker compose config -q

test-shellcheck:
	$(COMPOSE_RUN) shellcheck shellcheck -e SC2181 tests/*/*.sh actions/*/*.sh

unit-tests:
	$(COMPOSE_RUN) test make _unit-tests
_unit-tests:
	@find source/tests -name \*.sh -maxdepth 2 -print0 | xargs -0 -I {} echo 'echo Running {}; bash -e {}' | sort | sh -e
