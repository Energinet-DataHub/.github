.PHONY: all clean test

COMPOSE_RUN = docker compose run --rm --quiet-pull

export DOCKER_CLI_HINTS=false

all: clean test

clean:
	docker compose down --rmi all --remove-orphans

test: test-makefile test-docker test-editorcheck test-shellcheck test-github unit-tests

test-makefile:
	$(COMPOSE_RUN) makelint

test-docker:
	docker compose config -q

test-shellcheck:
	$(COMPOSE_RUN) shellcheck shellcheck -e SC2181 tests/*/*.sh actions/*/*.sh

test-editorcheck:
	$(COMPOSE_RUN) eclint

test-github:
	$(COMPOSE_RUN) test make _test-github-dependabot
	$(COMPOSE_RUN) test make _test-github-actions
	$(COMPOSE_RUN) test make _test-github-workflows
_test-github-actions:
	@find .github/actions actions -type f \( -iname \*.yaml -o -iname \*.yml \) -print0 | xargs -0 -I {} echo 'echo Checking: {}; check-jsonschema -q --builtin-schema github-actions {}' | sort | sh -e
_test-github-workflows:
	@find .github/workflows -type f \( -iname \*.yaml -o -iname \*.yml \) -print0 | xargs -0 -I {} echo 'echo Checking: {}; check-jsonschema -q --builtin-schema github-workflows {}' | sort | sh -e
_test-github-dependabot:
	check-jsonschema -q --builtin-schema dependabot .github/dependabot.yml

unit-tests:
	$(COMPOSE_RUN) test make _unit-tests
_unit-tests:
	@find tests -name \*.sh -maxdepth 3 -print0 | xargs -0 -I {} echo 'echo Running {}; bash -e {}' | sort | sh -e
