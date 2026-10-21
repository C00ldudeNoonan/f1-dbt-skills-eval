#!/usr/bin/env bash
# Interactive driver: you run the agent in its app, this script handles everything else.
#
#   harness/step.sh RUN_ID start      set up schemas + workspace, print how to open the session
#   harness/step.sh RUN_ID prompt T   apply pre-task breakage, copy task T's prompt to the clipboard
#   harness/step.sh RUN_ID nudge      log an intervention (any message you send besides the prompt)
#   harness/step.sh RUN_ID done T     grade, inject post-task data, rebuild, grade again
#   harness/step.sh RUN_ID summary    summary table for this run
#
# RUN_ID is ARM_N, for example A_1. Claude arms: [model prefix][A|B|C], where A = no skills,
# B = dbt-agent-skills available, C = skills + a CLAUDE.md telling the agent to use them;
# prefix none = Opus, S = Sonnet, H = Haiku (so SA_1, HB_2, HC_1, ...).
# W (Wizard, default model), WC (Wizard, Claude model).
set -euo pipefail

RUN_ID=$1; CMD=$2; T=${3:-}
ARM=${RUN_ID%%_*}
IS_CLAUDE=false; [[ $ARM =~ ^[SH]?[ABC]$ ]] && IS_CLAUDE=true
WITH_SKILLS=false; [[ $IS_CLAUDE == true && ( $ARM == *B || $ARM == *C ) ]] && WITH_SKILLS=true
case ${ARM:0:1} in S) CLAUDE_LABEL="Sonnet 5.5" ;; H) CLAUDE_LABEL="Haiku 5.5" ;; *) CLAUDE_LABEL="Opus 5.5" ;; esac
ROOT=$(cd "$(dirname "$0")/.." && pwd)
set -a; source "$ROOT/config.env"; set +a
PROJ="$RUNS_DIR/$RUN_ID/project"
RDIR="$ROOT/results/$RUN_ID"; LOGS="$RDIR/logs"
PY=("$ROOT/harness/py")
RAW="F1_RAW_${RUN_ID}"; TARGET="F1_DBT_${RUN_ID}"
# Suite: a run id containing _v2_ (for example HA_v2_1) uses the harder v2 tasks
if [[ $RUN_ID == *_v2_* || $RUN_ID == *_V2_* ]]; then SUITE=v2; TASKS=("$ROOT"/harness/tasks_v2/*.md); else SUITE=v1; TASKS=("$ROOT"/harness/tasks/*.md); fi
NTASKS=${#TASKS[@]}
pre_inject() {  # breakage applied right before a task's prompt
  case $SUITE:$1 in
    v1:5) inject drift ;; v1:6) inject dup_constructor ;;
    v2:5) inject drift_v2 ;; v2:6) inject dup_constructor; inject dup_standings ;;
    v2:9) inject vendor_b ;; v2:10) inject telemetry_initial ;;
  esac
}
post_inject() {  # new data arriving after the agent finishes a task
  case $SUITE:$1 in
    *:2) inject arrive1; inject correct_laps ;;
    v1:3) inject driver_change ;;
    v2:3) inject driver_change; inject orphan_result ;;
    v1:4) inject arrive2 ;;
    v2:4) inject arrive2; inject orphan_driver ;;
    v2:10) inject telemetry_late ;;
  esac
}

inject() { "${PY[@]}" "$ROOT/harness/inject.py" "$RUN_ID" "$1"; }
grade()  { "${PY[@]}" "$ROOT/harness/grade.py" "$RUN_ID" "$@" || echo "[grade] failed (continuing)"; }
now()    { date +%s; }

instructions() {
  echo
  echo "Workspace ready: $PROJ"
  echo
  if [[ $IS_CLAUDE == true ]]; then
    echo "Open it in the Claude app (Code tab):"
    echo "  - New session -> choose this folder. Turn worktrees OFF so it edits in place."
    echo "  - Model: $CLAUDE_LABEL, same effort level for every run."
    echo "  - Permission mode: Auto (approvals don't count as nudges)."
    echo "  - Turn off connectors and MCP servers for the session (dbt-internal-analytics, Fivetran Context, and so on)."
    [[ $ARM == *C ]] && echo "  - CLAUDE.md tells the agent to consult the dbt skills before each task."
    [[ $WITH_SKILLS == true ]] && echo "  - The pinned dbt skills are in .claude/skills, so they load as project skills."
  else
    local model=$WIZARD_MODEL; [[ $ARM == WC ]] && model=$WIZARD_CLAUDE_MODEL
    echo "Open it in the Wizard TUI, in place (not Wizard Desktop, which copies the repo elsewhere):"
    echo "  cd $PROJ && wizard -m $model \\"
    echo "    --disable browser_use --disable browser_use_external --disable in_app_browser \\"
    echo "    --disable computer_use --disable memories --dangerously-bypass-approvals-and-sandbox"
    echo "  (Approvals are bypassed so it runs unattended, like Auto mode in the Claude arms.)"
  fi
  echo
  echo "Then: harness/step.sh $RUN_ID prompt 1"
}

case $CMD in
start)
  [[ -e $PROJ ]] && { echo "$PROJ already exists; pick a new RUN_ID or delete it"; exit 1; }
  mkdir -p "$PROJ" "$LOGS"
  cat > "$PROJ/profiles.yml" <<EOF
f1:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: $SF_ACCOUNT
      user: $SF_USER
      authenticator: externalbrowser
      role: $SF_ROLE
      warehouse: $SF_WAREHOUSE
      database: $SF_DATABASE
      schema: $TARGET
      threads: 8
EOF
  case $IS_CLAUDE in
    true)
      # Project-scoped settings: no web tools in any Claude arm; *B arms get the pinned dbt skills.
      mkdir -p "$PROJ/.claude/skills"
      echo '{"permissions": {"deny": ["WebFetch", "WebSearch"]}}' > "$PROJ/.claude/settings.json"
      if [[ $WITH_SKILLS == true ]]; then
        cp -R "$ROOT/$SKILLS_DIR/skills/." "$PROJ/.claude/skills/"
      fi
      if [[ $ARM == *C ]]; then
        cp "$ROOT/harness/forced_skills_CLAUDE.md" "$PROJ/CLAUDE.md"
      fi
      rmdir "$PROJ/.claude/skills" 2>/dev/null || true
      ;;
  esac
  git -C "$PROJ" init -q
  git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "harness: initial" --author "harness <harness@eval>"
  inject setup
  instructions
  ;;

prompt)
  pre_inject "$T"
  sed -e "s/{DATABASE}/$SF_DATABASE/g" -e "s/{RAW_SCHEMA}/$RAW/g" -e "s/{TARGET_SCHEMA}/$TARGET/g" \
    "${TASKS[$((T-1))]}" | tee "$LOGS/t$(printf %02d "$T")_prompt.md" | pbcopy
  echo "$T start $(now)" >> "$RDIR/timeline.txt"
  echo "Task $T prompt copied to clipboard. Paste it into the session as-is and send."
  echo "Rules: don't help. If the agent asks a question, reply exactly:"
  echo "  \"Use your best judgment; I'm not available to answer questions.\""
  echo "and run: harness/step.sh $RUN_ID nudge"
  echo "When the agent says it's done: harness/step.sh $RUN_ID done $T"
  ;;

nudge)
  echo "${T:-?} nudge $(now)" >> "$RDIR/timeline.txt"; echo "logged"
  ;;

done)
  echo "$T end $(now)" >> "$RDIR/timeline.txt"
  git -C "$PROJ" add -A
  git -C "$PROJ" commit -qm "harness: after task $T" --author "harness <harness@eval>" --allow-empty
  "${PY[@]}" "$ROOT/harness/collect_transcript.py" "$RUN_ID" "$T" || true
  grade "$T" agent
  post_inject "$T"
  grade "$T" rebuild --build
  git -C "$PROJ" add -A
  git -C "$PROJ" commit -qm "harness: rebuild after task $T" --author "harness <harness@eval>" --allow-empty
  "${PY[@]}" "$ROOT/harness/publish_results.py" || true
  [[ $T -lt $NTASKS ]] && echo "Next: harness/step.sh $RUN_ID prompt $((T+1))" || echo "Run complete: harness/judge.sh $RUN_ID"
  ;;

summary)
  "${PY[@]}" "$ROOT/harness/summarize.py" "$RUN_ID"
  ;;

*) echo "unknown command $CMD"; exit 1 ;;
esac
