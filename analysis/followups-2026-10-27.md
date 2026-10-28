# Follow-up questions (2026-10-27)

Sources: the harness in this repo, per-run grades in `results/`, and the agents' session transcripts (`~/.claude/projects/-Users-<you>-f1-eval-workspaces-<RUN>-project/<session>.jsonl`, not published). Transcript references are `RUN transcript L<line>`.

## 1. Fresh context per ticket, or one session per run?

**One continuous session per run.** Every ticket after the first was sent into the same session that did ticket 1; no run got a fresh context per ticket.

- The protocol says so: `HARNESS.md:16` ("The tasks (one continuous session per run)") and `HARNESS.md:112` ("Use one continuous session per run, so tasks 2–7 go in the same chat").
- `harness/step.sh:115` (`prompt)`) only renders the ticket and records a start time; it never starts a session. Ticket 1 was sent by starting a session in the run's workspace, and every later ticket was sent as a message to that same session.
- Metrics collection assumes one session per workspace: `harness/collect_transcript.py:41-45` takes the single newest transcript in the run's project folder.
- Transcripts confirm it: all 17 runs have exactly **1 transcript file and 1 session ID**, and none contains a context-compaction marker. The session map (17 runs → 17 distinct session IDs) is in the private results.

Implication: later tickets had the full history of earlier ones in context. That's realistic for "one engineer owns the project", but it means a skill read on ticket 1 can still shape ticket 9.

## 2. Runs blocked by the auto-mode check on `dbt build --target prod`

**3 runs**, 4 denials in total, all on ticket 11 (slim CI), all with the reason `[Production Deploy]`:

| Run | Denials | First denial | Resolved by |
|---|---|---|---|
| SB_v2_1 | 2 | transcript L1948 | approval relayed from the orchestrating session (`results/SB_v2_1/timeline.txt:24`) |
| HA_v2_1 | 1 | transcript L2979 | your approval typed in the session (`results/HA_v2_1/timeline.txt:24`) |
| HC_v2_1 | 1 | transcript L3159 | refused the relayed approval; your approval typed in the session (`results/HC_v2_1/timeline.txt:23-24`) |

Denial text: "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Production Deploy]."

Two other runs had unrelated denials: A_v2_1 (transcript L964, a safety check on a broad `rm`) and B_v2_1 (transcript L1080, writing to the shared notes folder after it was locked).

## 3. Skill usage, runs × skills

Counted from each run's full transcript: **inv** = invoked with the Skill tool; **read** = a tool call that opened a file under `.claude/skills/<skill>/` (Read, `cat`, `grep`, and so on). Each tool call counts once per skill.

| Run | unit-test | semantic-layer | documentation | run-commands | analytics-eng | state | mesh | Total |
|---|---|---|---|---|---|---|---|---|
| B_1 | – | – | – | 1 read | – | – | – | 1 |
| SB_1 | 1 read | – | – | – | – | – | 2 read | 3 |
| SC_1 | – | – | – | 1 read | 2 read | – | 1 read | 4 |
| HB_1 | – | – | – | – | – | – | – | 0 |
| HC_1 | – | – | 10 read | – | – | – | – | 10 |
| B_v2_1 | – | 1 inv + 1 read | – | 1 inv | 1 inv | – | – | 4 |
| C_v2_1 | 2 read | 2 read | 3 read | – | 1 read | 1 read | 2 read | 11 |
| SB_v2_1 | – | 1 inv + 1 read | – | – | – | – | 1 read | 3 |
| SC_v2_1 | – | 2 read | – | – | 2 read | – | 2 read | 6 |
| HB_v2_1 | – | 1 inv + 2 read | – | – | – | – | – | 3 |
| HC_v2_1 | – | 1 read | 4 read | – | – | – | – | 5 |

Skills never opened by any run: `answering-natural-language-questions-with-dbt`, `configuring-dbt-mcp-server`, `fetching-dbt-docs`, `querying-the-dbt-information-schema`, `troubleshooting-dbt-job-errors`.

Columns: unit-test = `adding-dbt-unit-test`, semantic-layer = `building-dbt-semantic-layer`, documentation = `maintaining-dbt-documentation`, run-commands = `running-dbt-commands`, analytics-eng = `using-dbt-for-analytics-engineering`, state = `using-dbt-state`, mesh = `working-with-dbt-mesh`.

**Correction:** the published report and blog chart used a per-ticket count that counted every path mention inside one call, which over-counted the forced arm: HC_1 11 → 10, C_v2_1 13 → 11, SC_v2_1 9 → 6, HC_v2_1 6 → 5. The available-arm range (0–4) is unchanged.

## 4. Drift checks and build duration

The premise needs a correction first. **15 of 17 projects** added drift checks that query `information_schema` (all except B_v2_1 and SB_1), so this isn't specific to two runs. The two runs the report called slow were **HB_1** and **SC_v2_1**, not C_v2_1. All three comparisons are below, using the harness's own `dbt build` time after each ticket (`results/<RUN>/t<NN>_rebuild.json` → `harness_build.seconds`) against the same model's no-skills run.

**HB_1 vs HA_1 (Haiku, Round 1).** The drift check arrived in ticket 5 (`runs/HB_1/macros/tests/expected_columns.sql`):

| Ticket | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| HB_1 (s) | 9 | 10 | 10 | 11 | **775** | **780** | **810** |
| HA_1 (s) | 10 | 12 | 12 | 12 | 19 | 14 | 16 |
| Ratio | 1.0× | 0.8× | 0.8× | 0.9× | **40×** | **57×** | **50×** |

**C_v2_1 vs A_v2_1 (Opus, Round 2):** 0.8×–2.0× per ticket (median about 1.2×). No sustained slowdown.

| Ticket | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C_v2_1 (s) | 28 | 64 | 25 | 30 | 33 | 35 | 39 | 50 | 44 | 46 | 55 | 84 |
| A_v2_1 (s) | 22 | 31 | 23 | 24 | 29 | 28 | 35 | 53 | 37 | 60 | 40 | 62 |

**SC_v2_1 vs SA_v2_1 (Sonnet, Round 2):** 0.4×–1.3× per ticket. SC_v2_1's slow `information_schema` checks only showed up inside its own session during ticket 5; it switched them to `DESCRIBE` before finishing the ticket, so the harness rebuilds never saw them.

| Ticket | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| SC_v2_1 (s) | 12 | 89 | 98 | 88 | 90 | 27 | 27 | 30 | 28 | 109 | 29 | 38 |
| SA_v2_1 (s) | 11 | 99 | 238 | 95 | 96 | 48 | 24 | 42 | 24 | 82 | 25 | 38 |

Caveat: rebuilds ran while up to 17 sessions shared one warehouse, so differences under about 2× are mostly noise.

**Correction:** the blog's "Two runs added vendor-drift checks … about 10× slower" should read "One run's drift check made every later build 40–57× slower (about 13 minutes instead of 15 seconds); another hit the same problem mid-ticket and fixed it."

## 5. HC_1's "career starts" definition and skill reads

**No skill was open or recently read when HC_1 chose the definition.** The decision came at 20:20:46; the first skill read in the whole run came at 20:24:47, four minutes later and after `fct_results.sql` was already written. That read was `maintaining-dbt-documentation`, which has nothing to do with the definition.

The deciding turn (HC_1 transcript L302):

> "Non-starters (`Did not qualify`, `Did not prequalify`, and most `Withdrew` rows) have zero laps and no race, so I'll exclude them from career starts, which is how official starts are counted."

Sequence in the transcript:

| Line | Time | Event |
|---|---|---|
| L285 | 20:20:32 | Starts checking whether DNQ and withdrawn rows are "real race entries" |
| L302 | 20:20:46 | Decides to exclude non-starters (the quote above) |
| L383 | 20:22:27 | Writes `fct_results.sql` with `is_race_start` |
| L491–L549 | 20:24:47–20:25:24 | First skill reads: `maintaining-dbt-documentation` (5 calls) |
| L637 | 20:27:33 | "25,115 race starts (26,719 minus 1,604 non-starters)" |

The ticket defined the column as "distinct Grands Prix entered"; the agent swapped in the F1 convention for "starts" instead. That's a spec-reading error made independently of the skills. The `CLAUDE.md` nudge was in context, but no skill content was. So the blog shouldn't imply that forcing skills caused this miss, only that forcing them didn't prevent it.

## Corrections to the published report and blog

1. Drift-check slowdown: one run, 40–57×, not two runs at about 10× (Q4).
2. Skill-usage chart: re-render with the per-call counts above (Q3).
3. Defects chart: "Guardrail made builds slower" is 1 run (HB_1, skills available); SC_v2_1's was transient.
4. HC_1: no causal link between forced skills and the miss (Q5).

## Round 2 reruns (2026-10-27 to 2026-10-28)

Four more Round 2 (v2 suite, 12 tickets) runs, graded with the unchanged harness. No existing grade file was modified.

- **SB_v2_2** and **SB_v2_3** repeat SB_v2_1 (Sonnet 5.5, skills available).
- **S45A_v2_1** (no skills) and **S45B_v2_1** (skills available) run the same suite on Sonnet 4.5.

| Run | Model | Skills | Checks passed (all tickets) | Final ticket | Rebuild failures | Output tokens | dbt calls | Skill reads | Nudges | Blind review |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SB_v2_1 (original) | Sonnet 5.5 | available | 94/154 (61.0%) | — | 2 | 259,054 | 74 | 3 | 0 | 4.22 |
| SB_v2_2 | Sonnet 5.5 | available | 154/154 (100%) | 17/17 | 0 | 195,845 | 62 | 3 | 0 | 4.44 |
| SB_v2_3 | Sonnet 5.5 | available | 103/154 (66.9%) | 11/17 | 0 | 279,451 | 134 | 5 | 1 | 4.33 |
| S45A_v2_1 | Sonnet 4.5 | none | 58/154 (37.7%) | 6/17 | 6 (t7–t12) | 208,321 | 163 | 0 | 2 | 2.67 |
| S45B_v2_1 | Sonnet 4.5 | available | 105/154 (68.2%) | 12/17 | 0 | 251,164 | 138 | 0 | 1 | 3.00 |

"Checks passed" is summed over the post-rebuild grade of every ticket, the same as `results/run_summary.json`. Blind review is the mean of the rubric's 1–5 scores; every run was reviewed in an anonymized copy.

### What the reruns show

1. **The same arm can swing from 61% to 100%.** The three Sonnet 5.5 skills-available runs scored 61%, 100%, and 67%. Their review scores were close together (4.22–4.44).
   - The spread between repeats of one arm is wider than every gap between arms in the original Round 2.
   - So the single-run comparisons in the report and the blog (for example, SB_v2_1 at 61% against SA_v2_1 at 92% and SC_v2_1 at 100%) can't support a claim about skills.
   - SB_v2_3 dropped checks for the same reason as SB_v2_1: a mistake on an early ticket that carried into every later ticket.
     - On ticket 2, `is_podium` came out off by 1.
     - On ticket 6, it missed a lap-time correction to an older race (215 rows).
2. **Sonnet 4.5 is clearly weaker than Sonnet 5.5 on this suite, whatever the arm.**
   - Both S45 runs read their lap times incrementally and only looked back over the last 2 races, so neither picked up the ticket 6 correction to an older race.
   - Neither added the ticket 5 uniqueness test or the time spine.
   - S45A's harness build failed from ticket 7 to the end. It also built the Vendor B driver crosswalk wrong (4 drivers) and the vendor discrepancy mart wrong. Its warehouse scans ran 10.3× the raw table size on telemetry, against 0.5–0.9× for the other reruns.
   - Its 2.67 review is the lowest of any run in either round.
3. **S45B beat S45A, but not because of skills.** S45B never read a skill (0 skill reads across 12 tickets), so the 68% against 38% gap comes from the run, not the skills. With one run per arm, it's in the same range as the variance in point 1.
4. **The reviewer scored analysis separately from correctness.** S45B got 5/5 on the open-ended leadership questions, with teammate-relative pace, intervals, and stated confounders. Its testing and change hygiene got 2/5:
   - row_number() dedups in staging that hide duplicates
   - no source tests
   - exploration scripts committed

### Comparability caveats

- **S45 ticket 1 ran in bypassPermissions.** Auto mode isn't available for Sonnet 4.5. Both S45 runs moved to acceptEdits after ticket 1.
  - Neither mode has the prod-deploy check that auto mode applies, so ticket 11 (prod deploy) isn't comparable with the Sonnet 5.5 runs.
- **SB_v2_2 ticket 11:** the prod build went through auto mode without a user approval, unlike the original runs, where the check blocked it. Treat SB_v2_2's ticket 11 as not comparable.
- **S45A changed the global `~/.dbt/profiles.yml` twice, on ticket 1 (moved its project file over it) and ticket 11 (appended a profile).** It was restored both times. The project-local profiles already had the same targets, so grading wasn't affected, but this is an agent acting outside its workspace.
  - acceptEdits didn't prevent the ticket 11 edit.
- **Nudges:** each nudge was the standard text ("Please continue until the task is fully done…"), sent after the agent stopped partway through a ticket.
  - SB_v2_3: ticket 5.
  - S45A: tickets 9 and 12.
  - S45B: ticket 4. S45B sat idle for about 18 hours before that nudge, so its wall-clock total (1,462 min) is mostly waiting and isn't reported in the table.
- **CI probe fix:** dbt v2 records `dbt show --inline` queries as a model named `inline`, which is never built. That made the ticket 11 CI probe a false negative for SB_v2_3.
  - `harness/grade.py` now skips that node.
  - SB_v2_3's original grade file is unchanged. `grades/t11_ci_probe_note.md` records that the probe passed.
- **Review blinding is imperfect:** run ids still appear in schema names in the README and sources, as in the earlier reviews.
- **Metrics collection:** S45A's ticket 12 metrics were collected after the fact. A note line in `timeline.txt` had broken the parser, so it moved to `incidents.md`.

### Further corrections to the report and blog

5. Don't present SB_v2_1's 61% as an effect of skills availability. The two repeats of that arm scored 100% and 67%, so report the arm as a range, or say that one run per arm can't separate skills from run-to-run variance.
6. Add Sonnet 4.5 as a separate data point: weaker on correctness and in review than every Sonnet 5.5 run, and its skills-available run never read a skill.
