#!/bin/sh -l
set -eu

# Failure handling utility function
die() { echo "$*" 1>&2 ; exit 1; }

MCIX_BIN_DIR="/usr/share/mcix/bin"
MCIX_CMD="$MCIX_BIN_DIR/mcix"
PATH="$PATH:$MCIX_BIN_DIR"

# Validate required vars
: "${PARAM_API_KEY:?Missing required input: api-key}"
: "${PARAM_URL:?Missing required input: url}"
: "${PARAM_USER:?Missing required input: user}"
: "${PARAM_REPORT:?Missing required input: report}"

# Optional arguments
PROJECT="${PARAM_PROJECT:-}"
PROJECT_ID="${PARAM_PROJECT_ID:-}"

# 1) Fail if BOTH project and project-id were provided
if [ -n "$PROJECT" ] && [ -n "$PROJECT_ID" ]; then
  die "ERROR: Both 'project' and 'project-id' were provided. Please specify only one."
fi

# 2) Fail if NEITHER project or project-id were provided
if [ -z "$PROJECT" ] && [ -z "$PROJECT_ID" ]; then
  die "ERROR: You must provide either 'project' or 'project-id'." 
fi

# Build command to execute
CMD="$MCIX_CMD unit-test execute \
 -api-key \"$PARAM_API_KEY\" \
 -url \"$PARAM_URL\" \
 -user \"$PARAM_USER\" \
 -report \"$PARAM_REPORT\""

# Add optional project/project-id
[ -n "$PROJECT" ] && CMD="$CMD -project \"$PROJECT\""
[ -n "$PROJECT_ID" ] && CMD="$CMD -project-id \"$PROJECT_ID\""

# Add optional argument flags
[ -n "$PARAM_MAX_CONCURRENCY" ] && CMD="$CMD -max-concurrency $PARAM_MAX_CONCURRENCY"

# Test suite name
[ -n "$PARAM_TEST_SUITE" ] && CMD="$CMD -test-suite \"$PARAM_TEST_SUITE\""

# Ignore test failures
[ -n "$PARAM_IGNORE_TEST_FAILURES" ] && CMD="$CMD -ignore-test-failures"

echo "Executing: $CMD"

# Execute the command
# shellcheck disable=SC2086
sh -c "$CMD"
status=$?

echo "return-code=$status" >> "$GITHUB_OUTPUT"
echo "report=$PARAM_REPORT" >> "$GITHUB_OUTPUT"
exit "$status"
