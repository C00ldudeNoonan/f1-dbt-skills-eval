-- The incrementally maintained lap summary must equal a from-scratch
-- aggregation of fct_telemetry. Checked for every race that received samples
-- in the last var('telemetry_test_window_days') days of loads, so the check
-- covers exactly what recent incremental runs touched without rescanning all
-- telemetry.
with recent_races as (

    select distinct race_id
    from {{ ref('fct_telemetry') }}
    where loaded_at >= dateadd(
        day, -{{ var('telemetry_test_window_days') }},
        (select max(loaded_at) from {{ ref('fct_telemetry') }})
    )

),

expected as (

    select
        race_id,
        driver_id,
        lap,
        count(*) as samples,
        max(speed_kph)::number(6, 1) as max_speed_kph,
        round(avg(throttle_pct), 2)::number(6, 2) as avg_throttle_pct,
        round(count_if(throttle_pct >= 99) / count(*) * 100, 2)::number(6, 2) as full_throttle_pct,
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

(select 'missing or different in summary' as problem, * from expected
 minus
 select 'missing or different in summary', * from actual)
union all
(select 'extra or different in summary', * from actual
 minus
 select 'extra or different in summary', * from expected)
