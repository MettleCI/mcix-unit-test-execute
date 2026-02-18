#!/bin/sh
# Don't use -l here; we want to preserve the PATH and other env vars 
# as set in the base image, and not have it overridden by a login shell

# ███╗   ███╗███████╗████████╗████████╗██╗     ███████╗ ██████╗██╗
# ████╗ ████║██╔════╝╚══██╔══╝╚══██╔══╝██║     ██╔════╝██╔════╝██║
# ██╔████╔██║█████╗     ██║      ██║   ██║     █████╗  ██║     ██║
# ██║╚██╔╝██║██╔══╝     ██║      ██║   ██║     ██╔══╝  ██║     ██║
# ██║ ╚═╝ ██║███████╗   ██║      ██║   ███████╗███████╗╚██████╗██║
# ╚═╝     ╚═╝╚══════╝   ╚═╝      ╚═╝   ╚══════╝╚══════╝ ╚═════╝╚═╝
# MettleCI DevOps for DataStage       (C) 2025-2026 Data Migrators
#              _ _        _            _
#  _   _ _ __ (_) |_     | |_ ___  ___| |_
# | | | | '_ \| | __|____| __/ _ \/ __| __|
# | |_| | | | | | ||_____| ||  __/\__ \ |_
#  \__,_|_| |_|_|\__|     \__\___||___/\__|
#                           _
#   _____  _____  ___ _   _| |_ ___
#  / _ \ \/ / _ \/ __| | | | __/ _ \
# |  __/>  <  __/ (__| |_| | ||  __/
#  \___/_/\_\___|\___|\__,_|\__\___|
# 

set -eu

# Import MettleCI GitHub Actions utility functions
. "/usr/share//mcix/common.sh"

# -----
# Setup
# -----
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_LOG_DIR="/usr/share/mcix"
export MCIX_CMD="mcix" 
export MCIX_JUNIT_CMD="/usr/share/mcix/mcix-junit-to-summary"
export MCIX_JUNIT_CMD_OPTIONS="--annotations"
# Make us immune to runner differences or potential base-image changes
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

# We'll store the real command status here so the trap can see it
MCIX_STATUS=0
# Populated if command output matches: "It has been logged (ID ...)"
MCIX_LOGGED_ERROR_ID=""

# -------------------
# Validate parameters
# -------------------

require PARAM_API_KEY "api-key"
require PARAM_URL "url"
require PARAM_USER "user"
require PARAM_REPORT "report"

# Ensure PARAM_REPORT will always be /github/workspace/...
PARAM_REPORT="$(resolve_workspace_path "$PARAM_REPORT")"
mkdir -p "$(dirname "$PARAM_REPORT")"
report_display="${PARAM_REPORT#${GITHUB_WORKSPACE:-/github/workspace}/}"

# ------------------------
# Build command to execute
# ------------------------

# Start argv
set -- "$MCIX_CMD" unit-test execute

# Core flags
set -- "$@" -api-key "$PARAM_API_KEY"
set -- "$@" -url "$PARAM_URL"
set -- "$@" -user "$PARAM_USER"
set -- "$@" -report "$PARAM_REPORT"

# Mutually exclusive project / project-id handling (safe with set -u)
PROJECT="${PARAM_PROJECT:-}"
PROJECT_ID="${PARAM_PROJECT_ID:-}"
validate_project
[ -n "$PROJECT" ]    && set -- "$@" -project "$PROJECT"
[ -n "$PROJECT_ID" ] && set -- "$@" -project-id "$PROJECT_ID"

# Optional flags

# -max-concurrency (PARAM_MAX_CONCURRENCY)
if [ -n "${PARAM_MAX_CONCURRENCY:-}" ]; then
  set -- "$@" -max-concurrency "$PARAM_MAX_CONCURRENCY"
fi

# -ignore-test-failures (PARAM_IGNORE_TEST_FAILURES)
[ -n "${PARAM_IGNORE_TEST_FAILURES:-}" ] && set -- "$@" -ignore-test-failures

# -test-suite (PARAM_TEST_SUITE)
if [ -n "${PARAM_TEST_SUITE:-}" ]; then
  set -- "$@" -test-suite "$PARAM_TEST_SUITE"
fi

# ------------
# Step summary
# ------------
write_step_summary() {
  # Surface "logged error ID" failures (if detected)
  if [ -n "${MCIX_LOGGED_ERROR_ID:-}" ] && \
     [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -w "$GITHUB_STEP_SUMMARY" ]; then
    {
      echo "**❌ Error:** There was an error logged while running the command."
      if [ -n "${MCIX_LOGGED_ERROR_ID:-}" ]; then
        # Capture the log entry and include it in the summary for visibility. 
        grep "(ID ${MCIX_LOGGED_ERROR_ID}" ${MCIX_LOG_DIR}/*.log | sed -n 's/.*(ID [^)]*): //p' \
          || echo "(Failed to extract log details for ID ${MCIX_LOGGED_ERROR_ID})"
      fi
    } >>"$GITHUB_STEP_SUMMARY"
    # Set a workflow error annotation for visibility. This will show up in the 'Annotations' tab 
    # but it won't fail the action on its own (since some errors are "log and continue".)
    gh_error "MCIX Unit-Test Execute" "There was an error logged during the execution of 'mcix unit-test execute'"
  fi

  # Do we have a variable pointing to a JUnit XML file?
  if [ -z "${PARAM_REPORT:-}" ] || [ ! -f "$PARAM_REPORT" ]; then
    gh_warn "JUnit XML file not found" "Path: ${PARAM_REPORT:-<unset>}"

  # Do we have a junit-to-summary command available?
  elif [ -z "${MCIX_JUNIT_CMD:-}" ] || [ ! -x "$MCIX_JUNIT_CMD" ]; then
    gh_warn "JUnit summarizer not executable" "Command: ${MCIX_JUNIT_CMD:-<unset>}"

  # Did GitHub provide a writable summary file?
  elif [ -z "${GITHUB_STEP_SUMMARY:-}" ] || [ ! -w "$GITHUB_STEP_SUMMARY" ]; then
    gh_warn "GITHUB_STEP_SUMMARY not writable" "Skipping JUnit summary generation."

  # Generate summary
  else
    # Commenting out for now (too verbose.)
    # gh_notice "Generating step summary" "Running JUnit summarizer and appending to GITHUB_STEP_SUMMARY."

    # mcix-junit-to-summary [--annotations] [--max-annotations N] <junit.xml> [title]
    echo "Executing: $MCIX_JUNIT_CMD $MCIX_JUNIT_CMD_OPTIONS $PARAM_REPORT \"MCIX DataStage Compile\""
    "$MCIX_JUNIT_CMD" \
      "$MCIX_JUNIT_CMD_OPTIONS" \
      "$PARAM_REPORT" \
      "MCIX DataStage Compile"  >> "$GITHUB_STEP_SUMMARY" || \
      gh_warn "JUnit summarizer failed" "Continuing without failing the action."
  fi
}

# ---------
# Exit trap
# ---------
write_return_code_and_summary() {
  # Prefer MCIX_STATUS if set; fall back to $?
  rc=${MCIX_STATUS:-$?}

  echo "return-code=$rc" >>"$GITHUB_OUTPUT"
  echo "junit-path=$report_display" >>"$GITHUB_OUTPUT"

  [ -z "${GITHUB_STEP_SUMMARY:-}" ] && return

  write_step_summary
}

# -------
# Execute
# -------
# Check the repository has been checked out
if [ ! -e "/github/workspace/.git" ]; then
  die "Repo contents not found in /github/workspace. Did you forget to run actions/checkout before this action?"
fi

# Capture output so we can detect "It has been logged (ID ...)" failures.
tmp_out="$(mktemp)"
cleanup() { rm -f "$tmp_out"; }

# Combine summary/output writing + temp cleanup in a single EXIT trap.
trap 'write_return_code_and_summary; cleanup' EXIT

# Run the command, capture its output and status, but don't let `set -e` kill us.
set +e
"$@" 2>&1 | tee "$tmp_out"
MCIX_STATUS=$?
set -e

# If the known "logged error" signature occurred, stash details for the summary.
MCIX_LOGGED_ERROR_ID=""
if mcix_has_logged_error "$tmp_out"; then
  MCIX_LOGGED_ERROR_ID="$(mcix_extract_logged_error_id "$tmp_out")"
fi

# Let the trap handle outputs & summary using MCIX_STATUS
exit "$MCIX_STATUS"
