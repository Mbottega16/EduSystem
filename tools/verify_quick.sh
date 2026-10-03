#!/bin/bash
# Quick Godot verification: import art, run the full test suite, run the
# term balance simulation. Mac-only right now -- reads
# tools/godot_path.mac.txt, a Mac-specific path file kept SEPARATE from
# tools/godot_path.txt (which every .bat launcher reads for the Windows
# machine). Never write a Mac path into that file; never write a Windows
# path into this one.
#
#   tools/verify_quick.sh
#
# Exits non-zero the moment anything fails, prints which check failed and
# where the full log is. Run this before every commit that touches art/,
# scripts/, or data/ -- it is the fast subset of the project's own
# Verify.bat (import + tests + contract), not a replacement for the full
# walkthroughs (Play a Whole Term.bat / Trace a Day.bat) before a push.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_PATH_FILE="$ROOT/tools/godot_path.mac.txt"

if [ ! -f "$GODOT_PATH_FILE" ]; then
  echo "No tools/godot_path.mac.txt -- create it with the path to the Godot binary."
  exit 1
fi
GODOT="$(cat "$GODOT_PATH_FILE")"
if [ ! -x "$GODOT" ]; then
  echo "Godot not found or not executable at: $GODOT"
  exit 1
fi

cd "$ROOT"

# Safety net: the editor rewrote project.godot once, stripping every
# hand-written comment in it (confirmed a one-time first-open artifact,
# not a per-run risk, but cheap to guard anyway since it already bit us
# once). If this run strips it again, restore it rather than leave the
# working tree holding a comment-stripped version silently.
PROJECT_GODOT_BEFORE="$(git -C "$ROOT" hash-object project.godot)"

echo "== importing art =="
"$GODOT" --headless --path . --import

PROJECT_GODOT_AFTER="$(git -C "$ROOT" hash-object project.godot)"
if [ "$PROJECT_GODOT_BEFORE" != "$PROJECT_GODOT_AFTER" ]; then
  if git -C "$ROOT" diff --quiet -- project.godot; then
    : # changed during this run but matches HEAD again -- fine
  else
    echo "NOTE: project.godot changed during import -- check 'git diff project.godot'"
    echo "      before committing (it stripped the file's comments once already)."
  fi
fi

echo
echo "== running test suite =="
"$GODOT" --headless --path . res://tests/run.tscn > /tmp/edusystem_verify_tests.log 2>&1 || true
tail -5 /tmp/edusystem_verify_tests.log
if grep -q "ALL EDUSYSTEM CHECKS PASSED" /tmp/edusystem_verify_tests.log; then
  echo "TESTS: PASS"
else
  echo "TESTS: FAIL -- full log at /tmp/edusystem_verify_tests.log"
  exit 1
fi

echo
echo "== running balance contract check (24-day term sim) =="
"$GODOT" --headless --path . res://tools/sim.tscn -- 24 > /tmp/edusystem_verify_sim.log 2>&1 || true
tail -8 /tmp/edusystem_verify_sim.log
if grep -q "full room, perfect teaching.*ok" /tmp/edusystem_verify_sim.log; then
  echo "BALANCE CONTRACT: PASS"
else
  echo "BALANCE CONTRACT: FAIL or changed -- full log at /tmp/edusystem_verify_sim.log"
  exit 1
fi

echo
echo "ALL QUICK CHECKS PASSED"
