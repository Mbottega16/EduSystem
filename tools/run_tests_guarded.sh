#!/bin/bash
# Headless test suite with a hang guard. Mac/Linux twin of "Run Tests.bat".
#
#   tools/run_tests_guarded.sh
#
# Two steps, each under a timeout:
#   1. auto-import: `godot --headless --path . --import`. If the project does
#      not import cleanly (a parse error, a missing class_name, a bad PNG),
#      stop here with the first offending line, rather than letting the suite
#      silently skip whole sections.
#   2. the suite: res://tests/run.tscn. It must print the completion line
#      "ALL EDUSYSTEM CHECKS PASSED (N assertions)". Read N, not just PASSED.
#
# Exit codes: 0 passed, 1 failed, 2 a step hung and was killed at its timeout.
#
# Godot is found via $EDU_GODOT, then tools/godot_path.mac.txt.
# Timeouts (seconds): EDU_IMPORT_TIMEOUT (default 300), EDU_TEST_TIMEOUT (900).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_PATH_FILE="$ROOT/tools/godot_path.mac.txt"
IMPORT_LIMIT="${EDU_IMPORT_TIMEOUT:-300}"
TEST_LIMIT="${EDU_TEST_TIMEOUT:-900}"

if [ -n "${EDU_GODOT:-}" ]; then
  GODOT="$EDU_GODOT"
elif [ -f "$GODOT_PATH_FILE" ]; then
  GODOT="$(head -n 1 "$GODOT_PATH_FILE")"
else
  echo "No Godot path: set EDU_GODOT or create tools/godot_path.mac.txt."
  exit 1
fi
if [ ! -x "$GODOT" ]; then
  echo "Godot not found or not executable at: $GODOT"
  exit 1
fi

LOG_DIR="${TMPDIR:-/tmp}/edusystem-guard.$$"
mkdir -p "$LOG_DIR"
IMPORT_LOG="$LOG_DIR/import.log"
TEST_LOG="$LOG_DIR/tests.log"

# run_limited LABEL LIMIT LOG CMD... : run CMD with its output in LOG, kill it
# after LIMIT seconds. Returns CMD's exit code, or 124 if it was killed.
run_limited() {
  local label="$1" limit="$2" log="$3"
  shift 3
  "$@" > "$log" 2>&1 &
  local pid=$! start=$SECONDS
  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS - start >= limit )); then
      echo "$label: still running after ${limit}s -- killing it." >&2
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
  done
  wait "$pid"
  return $?
}

fail() {
  echo
  echo "$1"
  echo "Full log: $2"
  exit "${3:-1}"
}

echo "== 1/2 auto-import check (limit ${IMPORT_LIMIT}s) =="
run_limited "import" "$IMPORT_LIMIT" "$IMPORT_LOG" "$GODOT" --headless --path "$ROOT" --import
IMPORT_CODE=$?
if [ "$IMPORT_CODE" -eq 124 ]; then
  fail "IMPORT HUNG - killed at the ${IMPORT_LIMIT}s timeout. The project did not finish importing." "$IMPORT_LOG" 2
fi
if grep -q -E "Parse Error|Parse error|SCRIPT ERROR|Failed to load" "$IMPORT_LOG"; then
  grep -m 3 -E "Parse Error|Parse error|SCRIPT ERROR|Failed to load" "$IMPORT_LOG"
  fail "IMPORT FAILED - the project does not import cleanly. Fix the first error above, then re-run." "$IMPORT_LOG"
fi
if [ "$IMPORT_CODE" -ne 0 ]; then
  fail "IMPORT FAILED - Godot exited with code $IMPORT_CODE during import." "$IMPORT_LOG"
fi
echo "import clean."

echo
echo "== 2/2 test suite (limit ${TEST_LIMIT}s) =="
run_limited "tests" "$TEST_LIMIT" "$TEST_LOG" "$GODOT" --headless --path "$ROOT" res://tests/run.tscn
TEST_CODE=$?
tail -n 5 "$TEST_LOG"
if [ "$TEST_CODE" -eq 124 ]; then
  fail "TESTS HUNG - killed at the ${TEST_LIMIT}s timeout. The suite never finished." "$TEST_LOG" 2
fi
if grep -q -E "Parse Error|Parse error" "$TEST_LOG"; then
  fail "TESTS FAILED - a script did not compile, so the suite never ran." "$TEST_LOG"
fi
COMPLETION="$(grep -E "ALL EDUSYSTEM CHECKS PASSED" "$TEST_LOG" | tail -n 1)"
if grep -q -E "^FAILURES:" "$TEST_LOG"; then
  grep -E "^FAILURES:" "$TEST_LOG"
  grep -m 5 -E "\[FAIL\]" "$TEST_LOG"
  fail "TESTS FAILED - assertions failed (first ones above). The suite finished; it did not pass." "$TEST_LOG"
fi
if [ -z "$COMPLETION" ]; then
  fail "TESTS FAILED - no completion line. The suite did not finish." "$TEST_LOG"
fi
if [ "$TEST_CODE" -ne 0 ]; then
  fail "TESTS FAILED - Godot exited with code $TEST_CODE." "$TEST_LOG"
fi
echo
echo "TESTS PASSED: $COMPLETION"
echo "Full log: $TEST_LOG"
exit 0
