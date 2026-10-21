# F1 dbt agent eval

Does the latest model build and maintain a complex dbt project as well *without* dbt skills as with them? And how does a dbt-native harness (Wizard) compare?

## Arms

| Arm | Harness | Model | dbt knowledge |
|---|---|---|---|
| `A` | Claude Code | `CLAUDE_MODEL` | none: no skills, MCP, CLAUDE.md, or web |
| `B` | Claude Code | `CLAUDE_MODEL` | dbt-agent-skills @ pinned commit (`vendor/`) |
| `W` | Wizard | `WIZARD_MODEL` (GLM 5.3) | Wizard as shipped: built-in skills and validation loop |
| `WC` | Wizard | same Claude model as A/B | as `W`, isolates harness vs. model |

Web search and fetch are off in every arm, so you're measuring what the agent knows and can figure out from the data. All arms are driven interactively in their apps, with you only pasting prompts.

## The tasks (one continuous session per run)

| # | Task | What the harness does afterward | What's graded |
|---|---|---|---|
| 1 | Greenfield: 4 required marts | rebuild | answer keys for all 4 marts |
| 2 | Incremental `fct_lap_times` with correction lookback | **arrives** a held-out race and **reissues** lap times for the previous race | incremental config; exact lap data after a non-full-refresh build |
| 3 | `snp_drivers` snapshot, `current_number` | **changes** Verstappen's and Sainz's numbers | snapshot holds 2 versions; dim reflects current |
| 4 | Sprints in `fct_session_results`; standings by round; refactor season standings | **arrives** the 2nd held-out race | answer keys; season mart is derived from the by-round mart |
| 5 | *(before: harness renames and drops raw columns)* "the overnight run is failing" | rebuild | everything still matches |
| 6 | *(before: harness duplicates the Ferrari constructor row)* BI ticket | rebuild | fan-out fixed; an upstream uniqueness test exists |
| 7 | Contracts; `dim_drivers` v2 with v1 deprecated; unit tests | rebuild | manifest checks, plus both versions match their keys |

Every grade is cumulative: later tasks re-check every earlier model, so regressions show up. Each task is graded twice:
- **agent**: the state the agent left behind
- **rebuild**: after the harness injects new data and runs `dbt build` itself (never `--full-refresh`)

### Built-in traps (none are mentioned to the agents)
- Literal `\N` for nulls, and everything loaded as text.
- Fastest lap times as `m:ss.sss` strings.
- Pre-1991 dropped-score rules: summing race points gets 1988 wrong (Prost 105 raw vs. Senna 90 counted).
- Sprint points count toward standings.
- Sprint `resultId`s collide with GP `resultId`s.
- Future races in the calendar with no results yet, so the current season isn't complete.
- Red-flag "pit stops" longer than 60s, with `duration` stored as `m:ss.sss`.
- Shared drives in the 1950s.

### Data isolation
- Each run gets zero-copy clones: `F1_RAW_<RUN>` (agent's sources) and `ZZ_F1EVAL_TRUTH_<RUN>` (answer-key source).
- Legitimate data changes go to both schemas. Breakage (drift, duplicates) goes to raw only.
- Agent workspaces live in `RUNS_DIR`, outside this repo. Logs and grades stay in `results/`, which agents never see.

## Suite v2 (harder)

Use a run id containing `_v2_` (for example `HA_v2_1`) to run the 8-task v2 suite in `harness/tasks_v2/`. It's the v1 tasks plus:

| # | Added depth | What the harness does |
|---|---|---|
| 1 | 7 marts instead of 4: adds `fct_qualifying` (gap to pole), `mart_teammate_head_to_head`, and `fct_driver_race_pace` (green-flag laps only) | |
| 2 | Adds `fct_stints` (pit stop boundaries), which must stay correct incrementally | new race plus lap corrections |
| 3 | Adds late-arriving drivers: results for an unknown driver must survive, with a placeholder dim row | adds a result for driver 9001 |
| 4 | Adds `mart_alt_points_standings` (modern scoring with full countback, systems as data) | 2nd race arrives, driver 9001's record arrives |
| 5 | Heavier drift: table rename (`LAP_TIMES` → `LAP_TIMING`), `DD/MM/YYYY` dates, `''` nulls in qualifying, plus the v1 drift | |
| 6 | Second, unmentioned bug: resent standings rows for one race | |
| 7 | Adds groups and access, plus 4 required unit tests | |
| 8 | Semantic Layer: 6 named metrics (2 ratios), sliced by time | manifest checks |
| 9 | Second vendor feed (VB_*): own ids, `SURNAME Forename` without accents, sessions named by circuit location (repeats in 2020/2021), 11 planted conflicts. Build crosswalks and a discrepancy mart | feed generated from a salted hash, so no answer table exists in Snowflake |
| 10 | 20M rows of car telemetry with `_LOADED_AT`. Incremental fact plus lap summary, cost-aware | Abu Dhabi plus 3-week-late Las Vegas samples land; harness measures raw bytes scanned by the rebuild vs table size |
| 11 | Slim CI: prod/ci targets, prod artifacts, `scripts/ci.sh` with state:modified+ and defer | harness edits `mart_driver_standings_by_round`, runs `ci.sh`, and checks it built exactly that model and its downstream models into the CI schema |
| 12 | Vague leadership asks ("who overperforms their car?", "are pit stops faster?") | rubric only (judge dimension 9) |

The self-test covers every v2 answer key too.

**One-time prep for v2 tasks 10+:** `harness/py harness/inject.py PREP prep_telemetry` (generates ~20M telemetry rows into the holdout schema; already done).

### Arms

`C` = skills plus a one-line `CLAUDE.md` telling the agent to use them (for example `HC_1`). It tests whether the skills help when used, separately from whether models reach for them.

## One-time setup

1. **Wizard:** log in with `wizard login`.
2. *(Arm WC only)* Add Opus 5.5 as a Wizard model:
   - `wizard providers set-key anthropic` (paste the key on stdin)
   - `wizard providers set-model anthropic --id anthropic/claude-opus-5-5 --target anthropic/claude-opus-5-5`
   - `wizard providers enable anthropic`
3. **Get the data:** download <https://www.kaggle.com/datasets/rohanrao/formula-1-world-championship-1950-2020> and unzip the CSVs into `data/f1/`.
4. **Load and validate.** Each step opens a browser for Snowflake SSO once, then caches the token:
   ```bash
   harness/py scripts/load_raw.py data/f1
   harness/py harness/selftest.py     # must print ALL GOOD
   ```

## Running a session

You drive the agent in its app. `harness/step.sh` handles setup, breakage, prompts, and grading around it.

```bash
harness/step.sh A_1 start      # schemas + workspace; prints how to open the session
harness/step.sh A_1 prompt 1   # copies the task 1 prompt to your clipboard; paste it and send
harness/step.sh A_1 done 1     # when the agent finishes: grade, inject data, rebuild, grade
harness/step.sh A_1 prompt 2   # ...repeat through task 7
harness/step.sh A_1 summary
```

**Session setup**
- **A and B** run in the Claude app (Code tab):
  - Open `~/f1-eval-workspaces/<RUN>/project` with **worktrees off**.
  - Use Opus 5.5 at the same effort level every time, in Auto permission mode.
  - Turn off connectors and MCP servers for the session.
  - `start` writes a project `.claude/settings.json` that denies WebFetch and WebSearch. For arm B, it also copies the pinned dbt skills into `.claude/skills/`.
- **W and WC** run in the Wizard TUI in that same folder. `start` prints the exact command. Don't use Wizard Desktop: it copies the repo into its own workspace, so the grader would be looking at the wrong folder.

**Rules for a fair run**
- Paste the prompt as-is and stay hands-off.
- If the agent asks you anything, reply exactly *"Use your best judgment; I'm not available to answer questions."* Then log it with `harness/step.sh RUN nudge`.
- Run `done` only when the agent says it's finished.
- Use one continuous session per run, so tasks 2–7 go in the same chat.

**Batching:**
- Do at least **3 runs per arm**, and alternate arms (A_1, B_1, W_1, A_2, …) so a mid-experiment model or app update doesn't hit only one arm.
- After a run is graded and judged, drop its schemas so later agents can't browse earlier ones:
  ```bash
  harness/py harness/inject.py A_1 teardown
  ```
- **Blind review:** `harness/judge.sh A_1` makes an anonymized copy of the project and copies the rubric to your clipboard. Run it in a fresh Claude session.
- **Across all runs:** `uv run python harness/summarize.py` writes `results/summary.md`.

**What you can't fully control in the apps:** your org's built-in skills (Fivetran `tools:*`, `anthropic-skills:*`) still load in arms A and B. None of them teach dbt, but if the agent invokes one, it shows up in `skills_used` in the per-task metrics.

**Safety note:** agents work in their own schemas only because the prompt tells them to; they have the `TRANSFORMER` role in `ANALYTICS_DEV`. For a stricter setup, create a role that can only touch `F1_*` schemas and set `SF_ROLE`.

## Dashboard (dbt Charts)

`dashboard/` is a dbt Charts project. `step.sh ... done` refreshes its CSVs (`harness/publish_results.py`) after every grade, so the board stays current. The data stays local, never in Snowflake, so agents can't see their own grades.

```bash
cd dashboard && dct serve --port 8090   # then open http://localhost:8090/eval/
```

Use the **Task suite** selector to switch between v1 and v2.
