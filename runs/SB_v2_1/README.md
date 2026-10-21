# F1 analytics dbt project

Builds Formula 1 marts from the raw Ergast/Kaggle tables in `ANALYTICS_DEV.F1_RAW_SB_v2_1` (read-only) into `F1_DBT_SB_v2_1`.

```
dbt build --profiles-dir .
```

## Layout
| Layer | Schema | What lives there |
|---|---|---|
| `staging/f1` | `F1_DBT_SB_v2_1_staging` (views) | 1:1 with raw tables: rename, type, `\N` -> null, `m:ss.mmm` -> ms. No business logic. |
| `intermediate` | `F1_DBT_SB_v2_1_intermediate` (views) | Reusable logic: season completeness, official standings snapshot. |
| `marts` | `F1_DBT_SB_v2_1` (tables) | Published models with enforced contracts: `fct_results`, `dim_drivers`, `mart_driver_season_standings`, `mart_constructor_season_pit_stops`, `fct_qualifying`, `mart_teammate_head_to_head`, `fct_driver_race_pace`. |
| `seeds` | `F1_DBT_SB_v2_1_reference` | `official_world_champions` (regression lock for the standings logic). |

## Conventions
- Raw parsing lives only in `macros/clean_raw.sql`; marts never touch raw text.
- A season is *complete* when every race on its calendar has results (`int_season_status`); nothing is hard-coded to a year.
- Changing a published column means changing its contract in `_marts__models.yml` (breaking change for downstream teams).

## Data quirks
- Raw nulls are the literal string `\N` (plus a few empty strings in `q3`).
- `races.round`/`year` are text: `max(round)` as text picks round 9 over 17. Always cast.
- 2024 is incomplete in the raw data: rounds 23-24 have no results, so 2024 standings are as of round 22 and no 2024 champion is credited.
- 1983 Brazil: raw `position` is stale after a disqualification; `position_order` is correct and is used for `finish_position`.
- 2005 Australia: two lapped finishers have `position` = `\N` but numeric `position_text` (11, 14); treated as classified.
- Shared drives (1950s) give two result rows for one driver/race and two winners in 3 races.
- Standings come from the raw snapshot: summing race points does not match official totals before 1991 (drop-score rules) or from 2021 (sprint points).
- Qualifying 2005 race 255 has a Q1 of 16:42.640 (kept; flagged by a warn-level test).
- Pit stops exist for 2011-2024 only; 517 stops over 60 s (red flags) are excluded.

## Incremental models
`fct_lap_times` and `fct_stints` are incremental (delete+insert by `race_id`). Each run rebuilds every race newer than what is loaded plus the two most recent loaded races, so corrected laps for those races flow through without a full refresh. `fct_stints` uses the same window off its own latest races, which always covers whatever the lap table rewrote. Corrections to older races need `dbt build --full-refresh -s fct_lap_times fct_stints`. Recency is by (season, round), not race_id.

## Driver history and late-arriving drivers
- `snp_drivers` (schema `F1_DBT_SB_v2_1_snapshots`) is a type-2 snapshot (check strategy) of the drivers table; `dbt build` runs it. History only starts from the first snapshot run.
- `dim_drivers.current_number` is the permanent car number (null if none). `is_placeholder` marks drivers present in any feed (`int_driver_ids`) but missing from raw `drivers`; they get `unknown_<id>` / `Unknown driver <id>` until the real record lands, then show real values on the next run.
- `audit_results_missing_driver` lists orphan results (`select count(*)` for the number); a warn-level test fires while it is non-empty.

## Sessions, standings by round, what-if scoring
- `fct_session_results`: race + sprint entries; key is `(session_type, source_result_id)`. `dim_drivers.career_wins` is Grand Prix only; `career_sprint_wins` counts sprint wins.
- `mart_driver_standings_by_round` is the source of truth for official standings; `mart_driver_season_standings` selects each season's latest completed round from it.
- `mart_alt_points_standings` is driven by the `alt_points_systems` seed (`points_system, position_order, points`). To add a system (e.g. 1991-2002 10-6-4-3-2-1) append seed rows with a new name; no SQL change. The mart has one row per system, so filter `points_system = 'current'` for the current scoring.
- Note: the raw feed is live. A late-arriving test result (driver 9001, race 1143) appeared mid-project; staging's driver relationship test is warn-level by design.

## Vendor changes (read this when the overnight run fails)
The vendor's pipeline migration (renamed `lap_times` -> `lap_timing` and `positionorder` -> `position_order`, dropped `pit_stops.duration`, `races.date` now dd/mm/yyyy) is absorbed in staging only: sources use `identifier:` for table renames, staging selects the new column names, and `clean_date` accepts both date formats. Marts were verified row-for-row identical before and after, after a full refresh.

Safeguards:
- `on-run-start: check_source_schema` compares every column declared in `_f1__sources.yml` with the warehouse and aborts with one "VENDOR SCHEMA CHANGE DETECTED" report listing every missing table/column. Declare any new column staging reads under its source table.
- `matches_format` tests on source columns (dates, times, ids, points, ms) fail when values stop matching the format our parsing assumes, instead of silently becoming null.
- `dim_drivers` etc. keep their contracts; a breaking mart change shows up in the contract check.

## Raw data defects found and how they are handled
Found during the "Ferrari doubled" incident (vendor feed flaky):
| Defect | Effect | Handling |
|---|---|---|
| `constructors` has Ferrari (id 6) twice (second copy named `Ferrari ` with a trailing space) | `fct_results` join fanned out: Ferrari wins/points doubled | Staging dedupes every keyed table; `conflicting_duplicates` source tests fail if copies differ; row-count and constructor-total reconciliation tests on `fct_results` / `fct_session_results` |
| `driver_standings` has 23 exact duplicate rows for race 1142 (ids 73xxx and 173xxx) | duplicate standings rows by round | deduped on (race, driver) in staging |
| `lap_timing.milliseconds` is +137 ms off for 215 laps of race 1142 while `time` reconciles to the official race time | wrong lap times, stints and pace for that race | staging trusts `time`, keeps raw ms as `reported_lap_time_ms`; warn test `assert_lap_time_text_matches_milliseconds` |
Source `unique` tests are warn-level because staging self-heals exact duplicates; conflicting duplicates are errors. Note dbt builds a model before testing it, so tests stop downstream models but a bad table can already be live: run `dbt build` into a CI schema first for hard gating.

## Public interfaces and versions (for other dbt projects)
- Group `f1_analytics` (owner F1 Analytics) owns the two **public** models, `fct_results` and `dim_drivers`. Everything else is `protected` and must not be `ref`'d from other projects. Both public models have enforced contracts and `not_null` constraints on their keys.
- `dim_drivers` is versioned. **v2 is latest**: `full_name` is replaced by `first_name` + `last_name` (invariant: v1 `full_name` = `first_name || ' ' || last_name`; placeholder drivers are `Unknown` / `driver <id>`). **v1 is deprecated on 2027-01-01** and keeps building.
- Relations: `dim_drivers_v1`, `dim_drivers_v2`, and the unsuffixed view `dim_drivers`, which always points at the latest version (v2). Use `ref('dim_drivers')` for latest or `ref('dim_drivers', v=1)` to stay pinned. Non-dbt readers of `dim_drivers` that need `full_name` must switch to `dim_drivers_v1` or migrate to the new columns.
- Both versions come from `int_driver_profiles`, so placeholder rows for late-arriving drivers behave the same in each.

## Semantic Layer
Semantic models (latest spec) live in `_marts__models.yml`: `race_results` on `fct_results` (time dimension `race_date`, entity `driver`) and `drivers` on `dim_drivers` (entity `driver`, nationality and names). `time_spine_daily` (1950-2035) backs `metric_time`.

Metrics: `race_starts`, `wins`, `podiums`, `championship_points` (simple), `podium_rate`, `points_per_start` (ratios over `race_starts`). Dimensions: `race_result__season`, `race_result__round`, `race_result__constructor_name`, `driver__nationality`, `driver__driver_ref`, `driver__first_name`/`last_name`, `metric_time` (any grain; it is `race_date`).

Validate locally (Fusion's `dbt sl` needs the dbt platform, so use MetricFlow): `dbt parse && uvx --from "dbt-metricflow[dbt-snowflake]" mf validate-configs`. Example queries (`mf query` locally, `dbt sl query` on the platform):
```
# constructors in 2023
mf query --metrics wins,podiums,race_starts,championship_points,podium_rate,points_per_start \
  --group-by race_result__constructor_name --where "{{ Dimension('race_result__season') }} = 2023" --order=-championship_points
# wins by driver nationality
mf query --metrics wins,race_starts --group-by driver__nationality --order=-wins --limit 10
# one driver's podium rate by year
mf query --metrics podium_rate --group-by metric_time__year,driver__last_name \
  --where "{{ Dimension('driver__last_name') }} = 'Hamilton'" --order metric_time__year
# points per start by season
mf query --metrics points_per_start --group-by race_result__season --order race_result__season
```
Notes: metrics count Grand Prix entries only (sprints and sprint points are excluded, so `championship_points` is race points, not official standings points). `driver__*` dimensions come from `dim_drivers`, so drivers with no real record show as placeholders.

## Vendor B cross-check feed
Vendor B (`vb_drivers`, `vb_sessions`, `vb_results`, 2018-2024) uses its own keys, so it is mapped automatically:
- `dim_driver_crosswalk` (Vendor B `driver_key` -> our `driver_id`): manual override seed, then accent/case/word-order-insensitive full name (`HULKENBERG Nico` = `Nico Hülkenberg`), then three-letter abbreviation = our driver code (resolves `Alex`/`Alexander Albon`). Candidates are only our drivers active in Vendor B's seasons; a tier matches only when it hits exactly one driver, and name vs abbreviation disagreement is left unmatched. Racing numbers are deliberately not used (reused by different drivers, e.g. 3, 2, 9).
- `dim_session_crosswalk` (`session_key` -> `race_id`, `session_type`): override seed, then date: same season and Vendor B's UTC start date within one day of our race date (race sessions) or sprint date (sprints), nearest wins, ties broken by meeting name = circuit location. The UTC start can have a missing time (`2021-07-17T\N Z`); only the date is used.
- Both crosswalks keep unmatched rows with a null id, and `not_null`/`unique` tests (plus `assert_vendor_b_results_fully_mapped` and `assert_vendor_b_driver_matches_share_results`) fail the build loudly. For a genuinely ambiguous case add a row to `seeds/vendor_b_driver_overrides.csv` or `seeds/vendor_b_session_overrides.csv`; normally both are empty. New seasons need no changes.
- `mart_vendor_result_discrepancies`: full outer comparison over Vendor B's seasons. Types: `points`, `position` (classified positions; unclassified in both = no discrepancy), `missing_in_vendor_b`, `missing_in_vendor_a`. For `missing_*` rows the side that has the entry shows its points. Our feed remains the system of record.

## Telemetry (`fct_telemetry`, `mart_lap_telemetry_summary`)
~20M raw samples (2022+, `CAR_TELEMETRY`, each with `_loaded_at`). Both models are incremental and never rescan the raw table in routine runs.
- **Filter on ingestion time, not event time.** `fct_telemetry` reads only raw rows with `_loaded_at >= (max(loaded_at) already loaded - 15 min)`. A late sample (old race, new `_loaded_at`) is therefore picked up, whereas a `recorded_at` filter would never see it. The raw table is naturally ordered by load time, so this prunes to the newest micro-partitions. `stg_f1__car_telemetry` is a bare rename view on purpose: a window function or dedupe there would block that pushdown.
- **Merge by key** (`race_id, driver_id, lap, sample_index`), deduplicated within the batch keeping the newest `_loaded_at`, so a re-sent corrected sample replaces the old one. The merge target is pruned to the races in the batch (`incremental_predicates` against the batch table). The 15 minute lookback only guards loader clock skew; re-reading is idempotent.
- **Summary stays correct without refreshes.** A lap's aggregate depends on all its samples, so `mart_lap_telemetry_summary` finds laps touched since its own high-water mark (`last_loaded_at`), re-aggregates those laps in full from `fct_telemetry`, and merges them.
- **Tests are scoped to recent loads** (3 days before the newest load) so they do not rescan 20M rows. Whole-table checks belong in a full refresh/CI run.
- `telemetry_raw_schema` var repoints the telemetry source (used to simulate late arrivals in a scratch schema); `telemetry_lookback_minutes` tunes the lookback. Always include `stg_f1__car_telemetry` in a selection when pointing the source elsewhere, since it is a view.
- **Cost (measured, X-Small-ish warehouse):** full build = ~5 s and ~680 MB scanned for `fct_telemetry` (+ ~1-2 s, ~580 MB for the summary), writing 19.8M rows. A routine run with a new race = ~1-3 s, ~10-120 MB scanned, ~250k rows merged; with nothing new the window queries scan ~0 MB. Tests add ~15-80 MB.
- Verified in a scratch copy: a new race, late samples for an old lap, and a re-sent corrected sample all landed, and both tables matched a recomputation from the source (row hash equal, summary identical).

## CI (pull requests build only what changed)
Targets in `profiles.yml`: `dev` (default), `prod` (`F1_DBT_SB_v2_1_PROD*` schemas) and `ci` (`F1_DBT_SB_v2_1_CI*` schemas).

- **Prod state.** `scripts/prod_build.sh` runs a full `dbt build --target prod` and copies `manifest.json`, `run_results.json` (and `semantic_manifest.json`) from `target/` into `prod-artifacts/`. Run it after each merge to main and commit the refreshed artifacts; they are what CI compares against.
- **PR run.** `scripts/ci.sh` (project root, no arguments) selects `state:modified.body+ state:modified.configs+ state:modified.contract+ state:modified.macros+ state:new+` against `prod-artifacts/`, i.e. changed or new models, seeds, tests and anything downstream, and runs `dbt build --target ci --defer --state prod-artifacts --favor-state`. Unselected upstream models are read from prod, not rebuilt. The script prints the selected nodes first and exits non-zero on any build or test failure (or if the artifacts are missing).
- `state:modified.relation` is deliberately not used: artifacts are built against prod schemas and CI builds into its own, so every relation would look changed.
- Changes to macros, `dbt_project.yml` or sources show up through the macro/config selectors. The incremental telemetry models are rebuilt from scratch in the CI schema if they are selected (about 20M rows, seconds on this warehouse).
- The CI schemas are not dropped automatically; drop `F1_DBT_SB_v2_1_CI*` periodically.
- Verified: right after a prod build `scripts/ci.sh` selects nothing and exits 0; changing one model builds just that model, its downstream models and their tests into `F1_DBT_SB_v2_1_CI*` (upstream is read from prod); a broken model makes it exit non-zero.

## Analysis: driver overperformance and pit stop trends
`docs/analysis_leadership_questions.md` answers "which drivers overperform their car" (`mart_driver_overperformance`, built on
teammate comparisons with a teammate-quality adjustment) and "are pit stops getting faster" (`mart_pit_stop_season_trend`,
circuit-adjusted). It documents the definitions, assumptions and limits. Tunable thresholds: vars `overperformance_min_*`,
`teammate_max_abs_delta_pct`, `rating_iterations`, `rating_ridge_lambda`.

