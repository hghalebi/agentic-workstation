install:
    ./install-agentic-tools.sh

install-minimal:
    ./install-agentic-tools.sh --profile minimal

install-factory:
    ./install-agentic-tools.sh --profile factory

install-agent-runner:
    ./install-agentic-tools.sh --profile agent-runner

install-local-llm:
    ./install-agentic-tools.sh --profile local-llm

doctor:
    ./scripts/doctor.sh

doctor-json:
    ./scripts/doctor.sh --json

auth:
    ./scripts/auth-status.sh

plan profile="coding-agent":
    ./install-agentic-tools.sh --profile {{profile}} --plan

json-plan profile="coding-agent":
    ./install-agentic-tools.sh --profile {{profile}} --json-plan

lint:
    bash -n install-agentic-tools.sh scripts/*.sh cloud/*.sh
    shellcheck install-agentic-tools.sh scripts/*.sh cloud/*.sh
    shfmt -i 2 -ci -d install-agentic-tools.sh scripts/*.sh cloud/*.sh

audit:
    ./scripts/verify-lockfile.sh
    ./scripts/audit-remote-installers.sh

test-docker:
    docker build -f tests/Dockerfile.ubuntu-24.04 .

snapshot-clean:
    ./scripts/prepare-snapshot.sh
