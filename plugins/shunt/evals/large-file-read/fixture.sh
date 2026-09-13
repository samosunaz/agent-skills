#!/usr/bin/env bash
# The runner sets CWD to the run's workspace; the log has to live there, because
# a case directory is outside the agent's reachable tree.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cp "$here/fixtures/gateway.log" ./gateway.log
