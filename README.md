# F1 dbt skills eval

Do coding agents still need dbt skills? This repo is the harness, data, and results from an experiment that ran 17 agents (Claude Opus 5.5, Sonnet 5.5, and Haiku 5.5) through up to 12 tickets each on a Formula 1 dbt project in Snowflake, with and without the [dbt agent skills](https://github.com/dbt-labs/dbt-agent-skills).

**Short answer:** skills didn't decide correctness. 11 of 17 runs passed every answer-key check, and 5 of the 6 that didn't had skills available or forced. Every failure came from process (tests that hard-coded today's answers, a stale backup restored without checking, a spec detail missed), not from missing dbt knowledge. Skills gave a small lift to blind code-review scores on the easier round that mostly disappeared on the harder one.

Write-up: _blog post link coming soon_

## What's in here

| Path | What it is |
|---|---|
| `harness/` | The eval harness: Snowflake loading and injection (`inject.py`), answer keys and grading (`grade.py`, `v2_extras.py`), the per-ticket driver (`step.sh`), transcript metrics, the blind-review rubric, and the self-test |
| `harness/tasks/`, `harness/tasks_v2/` | Ticket prompts for Round 1 (7 tickets) and Round 2 (12 tickets), exactly as the agents received them |
| `scripts/load_raw.py` | Loads the Kaggle CSVs into Snowflake as text and holds back the last two races |
| `results/` | Per-run grades for every ticket (agent state and post-rebuild), process metrics, blind-review scores, and summaries |
| `results/contamination/` | Notes agents left each other in a shared folder before we locked it (see Caveats) |
| `runs/` | Final state of all 17 agent-built dbt projects, minus build output and credentials |
| `dashboard/` | A [dbt Charts](https://docs.getdbt.com/guides/dbt-charts) board over the results (`cd dashboard && dct serve`) |
| `report/` | The results report page and the script that renders the blog charts |
| `HARNESS.md` | The original working notes for the harness |

## Run names

`<model><arm>_<n>` for Round 1 and `<model><arm>_v2_<n>` for Round 2:

- Model prefix: none = Opus, `S` = Sonnet, `H` = Haiku
- Arm: `A` = no skills, `B` = skills available, `C` = skills forced (skills plus a one-line `CLAUDE.md` telling the agent to use them)

For example, `SB_v2_1` is Sonnet with skills available on Round 2.

## How grading works

After each ticket the harness:

1. **Injects data:** held-back races, reissued lap corrections, driver changes, vendor schema drift, planted duplicates, a second vendor feed, or late-arriving telemetry, depending on the ticket.
2. **Rebuilds:** runs `dbt build` itself, never with `--full-refresh`.
3. **Grades:** compares each required model row by row with an answer key computed from a clean truth schema (legitimate changes only, no breakage), plus structural checks from `manifest.json` (incremental config, snapshots, contracts, versions, CI behavior, telemetry bytes scanned).

Grades are cumulative: later tickets re-check every earlier model. Vendor-feed IDs and planted conflicts come from a salted hash, so no answer table exists in the warehouse for an agent to find.

## Reproducing it

You need Snowflake, dbt v2 (dbt Fusion), [uv](https://docs.astral.sh/uv/), and an agent you can drive one ticket at a time.

1. Copy `config.example.env` to `config.env` and fill in your Snowflake account, user, role, warehouse, and database, plus a random `EVAL_SALT`.
2. Download the [Kaggle F1 dataset](https://www.kaggle.com/datasets/rohanrao/formula-1-world-championship-1950-2020) into `data/f1/`.
3. Load and validate:
   ```bash
   harness/py scripts/load_raw.py data/f1
   harness/py harness/inject.py PREP prep_telemetry
   harness/py harness/selftest.py   # must print ALL GOOD
   ```
4. For each run, `harness/step.sh RUN start`, then for each ticket `harness/step.sh RUN prompt N` (paste the prompt into the agent) and `harness/step.sh RUN done N` when the agent finishes.
5. For the dbt-agent-skills arms, clone `dbt-labs/dbt-agent-skills` at commit `ef57108` into `vendor/` (or set `SKILLS_DIR`).

## Caveats

- **One run per cell.** Each model × arm × round ran once; treat individual gaps as hints.
- **Shared notes.** The agent app gave sessions a shared notes folder, and agents traded data findings through it. Eight runs read another run's notes, mostly during Round 2's first ticket, before the folder was locked. `results/run_extra.json` lists which.
- **Interventions.** Three runs needed a human to approve a prod build that the agent's safety check blocked; two runs got one nudge each. All are in each run's `timeline.txt`.
- **Grader fixes.** Three grader bugs were fixed mid-experiment and affected tickets regraded; agents never saw grades.
- **Semantic Layer** queries weren't executed (`dbt sl` needs a dbt platform connection); that ticket is graded on definitions.

The F1 data comes from the Ergast archive via Kaggle and isn't redistributed here.
