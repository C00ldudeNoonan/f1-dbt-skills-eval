-- The incremental lap summary must equal a from-scratch aggregation of
-- fct_telemetry. Checked for the races touched in the recent test window
-- (var telemetry_test_window_days) to keep the cost bounded.
{%- set window = "dateadd(day, -" ~ var('telemetry_test_window_days') ~ ", current_timestamp())" %}
with recent_races as (
    select distinct race_id from {{ ref('fct_telemetry') }} where ingested_at > {{ window }}
),

expected as (
    select
        race_id, driver_id, lap,
        count(*) as samples,
        max(speed_kph) as max_speed_kph,
        avg(throttle_pct)::number(6, 2) as avg_throttle_pct,
        (100 * count_if(throttle_pct >= 99) / count(*))::number(6, 2) as full_throttle_pct,
        count_if(brake) as brake_samples
    from {{ ref('fct_telemetry') }}
    where race_id in (select race_id from recent_races)
    group by 1, 2, 3
),

actual as (
    select race_id, driver_id, lap, samples, max_speed_kph, avg_throttle_pct, full_throttle_pct, brake_samples
    from {{ ref('mart_lap_telemetry_summary') }}
    where race_id in (select race_id from recent_races)
)

(select 'missing_or_wrong_in_summary' as problem, * from expected minus select 'missing_or_wrong_in_summary', * from actual)
union all
(select 'extra_in_summary', * from actual minus select 'extra_in_summary', * from expected)
