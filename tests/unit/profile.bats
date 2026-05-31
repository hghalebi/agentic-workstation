#!/usr/bin/env bats

setup() {
  export STATE_DIR="${BATS_TEST_TMPDIR}/state"
  export MANIFEST_PATH="${STATE_DIR}/manifest.json"
}

@test "json plan is valid for coding-agent" {
  run bash -c './install-agentic-tools.sh --profile coding-agent --json-plan | jq -e ".profile == \"coding-agent\""'
  [ "$status" -eq 0 ]
}

@test "unknown profile fails" {
  run ./install-agentic-tools.sh --profile nope --dry-run
  [ "$status" -ne 0 ]
}

@test "only filter enables requested module and filters others" {
  run bash -c './install-agentic-tools.sh --profile coding-agent --only agents --json-plan | jq -e ".modules[] | select(.name == \"agents\" and .enabled == true)"'
  [ "$status" -eq 0 ]
  run bash -c './install-agentic-tools.sh --profile coding-agent --only agents --json-plan | jq -e ".modules[] | select(.name == \"base\" and .reason == \"only-filter\")"'
  [ "$status" -eq 0 ]
}

@test "skip filter disables requested module" {
  run bash -c './install-agentic-tools.sh --profile coding-agent --skip agents --json-plan | jq -e ".modules[] | select(.name == \"agents\" and .enabled == false and .reason == \"skip-filter\")"'
  [ "$status" -eq 0 ]
}

@test "resume marker is reflected in plan" {
  mkdir -p "${STATE_DIR}/installed"
  touch "${STATE_DIR}/installed/base"
  run bash -c './install-agentic-tools.sh --profile coding-agent --resume --json-plan | jq -e ".modules[] | select(.name == \"base\" and .reason == \"resume-marker\")"'
  [ "$status" -eq 0 ]
}

@test "doctor json is valid" {
  run bash -c './scripts/doctor.sh --profile minimal --json | jq -e ".profile == \"minimal\""'
  [ "$status" -ne 2 ]
}
