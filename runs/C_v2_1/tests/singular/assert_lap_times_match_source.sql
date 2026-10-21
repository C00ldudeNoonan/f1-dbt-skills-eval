{{ config(severity='warn') }}

-- Drift check for the incremental fct_lap_times: every lap in the source
-- should be in the table with the same time, and nothing extra. A failure
-- means a correction arrived for a race outside the reload window. Run
-- `dbt build --select fct_lap_times+ --full-refresh` to pick it up.

with source_laps as (
    select race_id, driver_id, lap, position, lap_time_ms
    from {{ ref('stg_f1__lap_times') }}
),

modelled_laps as (
    select race_id, driver_id, lap, position, lap_time_ms
    from {{ ref('fct_lap_times') }}
)

(select 'missing_or_changed' as issue, * from source_laps
 minus
 select 'missing_or_changed', * from modelled_laps)
union all
(select 'unexpected', * from modelled_laps
 minus
 select 'unexpected', * from source_laps)
