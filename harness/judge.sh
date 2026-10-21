#!/usr/bin/env bash
# usage: harness/judge.sh RUN_ID
# Makes an anonymized copy of a finished project and copies the rubric prompt to the clipboard.
# Open the printed folder in a fresh Claude app session (no worktree, no connectors), paste,
# then save the JSON reply to results/RUN_ID/judge.json.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
set -a; source "$ROOT/config.env"; set +a
RUN_ID=$1
# Random folder name so the judge can't infer the arm
DEST="$RUNS_DIR/judge/$(uuidgen | cut -c1-8)/project"
mkdir -p "$(dirname "$DEST")"
cp -R "$RUNS_DIR/$RUN_ID/project" "$DEST"
rm -rf "$DEST/target" "$DEST/logs" "$DEST/.claude" "$DEST/profiles.yml" "$DEST/.wizard"
echo "$RUN_ID -> $DEST" >> "$ROOT/results/judge_map.txt"
pbcopy < "$ROOT/harness/judge_prompt.md"
echo "Judge folder: $DEST"
echo "Rubric prompt copied. Save the reply to: $ROOT/results/$RUN_ID/judge.json"
