#!/usr/bin/env bash
# usage: harness/judge_prep.sh RUN_ID  -> prints the anonymized project path
# Copies a finished project, strips everything that reveals the arm (skills, CLAUDE.md,
# profiles, build artifacts) from the files *and* from git history, under a random folder name.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
set -a; source "$ROOT/config.env"; set +a
RUN_ID=$1
CODE=$(uuidgen | cut -c1-8 | tr 'A-Z' 'a-z')
DEST="$RUNS_DIR/judge/$CODE/project"
mkdir -p "$(dirname "$DEST")"
cp -R "$RUNS_DIR/$RUN_ID/project" "$DEST"
cd "$DEST"
rm -rf target logs .claude profiles.yml CLAUDE.md .wizard dbt_packages prod-artifacts
git checkout -q -B judge HEAD 2>/dev/null || true
git add -A && git -c user.name=reviewer -c user.email=r@x commit -qm 'remove local config' --allow-empty
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --index-filter \
  'git rm -r -q --cached --ignore-unmatch .claude CLAUDE.md profiles.yml' -- --all >/dev/null 2>&1 || true
git for-each-ref --format='%(refname)' refs/original | xargs -n1 git update-ref -d 2>/dev/null || true
git reflog expire --expire=now --all && git gc -q --prune=now
mkdir -p "$ROOT/results/$RUN_ID"
echo "$RUN_ID $CODE $DEST" >> "$ROOT/results/judge_map.txt"
echo "$DEST"
