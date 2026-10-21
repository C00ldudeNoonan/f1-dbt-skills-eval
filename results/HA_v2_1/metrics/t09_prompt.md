We've licensed a second data feed, "Vendor B", covering 2018–2024 to cross-check our primary feed. It has landed in the raw schema as `VB_DRIVERS`, `VB_SESSIONS`, and `VB_RESULTS`. It uses its own ids and conventions and shares none of our ids, so work out how it maps from the data itself.

1. `dim_driver_crosswalk`: one row per Vendor B driver, with `driver_key` (Vendor B's) and `driver_id` (ours).
2. `dim_session_crosswalk`: one row per Vendor B session, with `session_key`, `race_id`, and `session_type` ('race' or 'sprint').
3. `mart_vendor_result_discrepancies`: one row per entry per discrepancy wherever the feeds disagree on 2018–2024 Grand Prix and sprint results. Columns: `race_id, session_type, driver_id, discrepancy_type` (one of 'points', 'position', 'missing_in_vendor_b', 'missing_in_vendor_a'), `vendor_a_value`, `vendor_b_value`. 'position' compares classified finishing positions; an entry that's unclassified in both feeds isn't a position discrepancy. Our primary feed stays the system of record.

Matching must be automatic and keep working as new seasons arrive. A small seed of manual overrides is fine for genuinely ambiguous cases, but not a hand-maintained list of every id. The build must fail loudly if any Vendor B driver or session can't be matched. Make sure `dbt build` succeeds when you're done, and explain how the matching works.
