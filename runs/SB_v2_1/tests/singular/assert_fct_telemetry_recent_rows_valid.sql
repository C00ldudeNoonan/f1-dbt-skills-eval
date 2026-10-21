-- Quality checks scoped to recently loaded samples (3 days before the newest load) so a routine run does not
-- rescan the full ~20M-row table. Checks: key unique and complete, throttle in 0-100, positive speed.
-- Whole-table verification belongs in a full refresh / CI run.
with recent as (
    select *
    from {{ ref('fct_telemetry') }}
    where loaded_at >= dateadd(day, -3, (select max(loaded_at) from {{ ref('fct_telemetry') }}))
),
bad_rows as (
    select race_id, driver_id, lap, sample_index, 'null key or timestamp' as problem
    from recent
    where race_id is null or driver_id is null or lap is null or sample_index is null or recorded_at is null or loaded_at is null
    union all
    select race_id, driver_id, lap, sample_index, 'throttle out of range'
    from recent where throttle_pct < 0 or throttle_pct > 100
    union all
    select race_id, driver_id, lap, sample_index, 'non-positive speed'
    from recent where speed_kph <= 0
    union all
    select race_id, driver_id, lap, sample_index, 'duplicate key'
    from recent
    group by race_id, driver_id, lap, sample_index
    having count(*) > 1
)
select * from bad_rows
