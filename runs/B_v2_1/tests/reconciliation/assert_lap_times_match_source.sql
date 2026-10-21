-- fct_lap_times is incremental and only re-reads the most recent races. If the
-- provider ever corrects an older race, this flags it: run with --full-refresh.
{{ config(severity='warn') }}

with source_laps as (
    select race_id, count(*) as laps, sum(lap_time_ms) as total_ms
    from {{ ref('stg_ergast__lap_times') }}
    group by race_id
),

model_laps as (
    select race_id, count(*) as laps, sum(lap_time_ms) as total_ms
    from {{ ref('fct_lap_times') }}
    group by race_id
)

select
    coalesce(source_laps.race_id, model_laps.race_id) as race_id,
    source_laps.laps        as source_laps,
    model_laps.laps         as model_laps,
    source_laps.total_ms    as source_total_ms,
    model_laps.total_ms     as model_total_ms
from source_laps
full outer join model_laps
    on source_laps.race_id = model_laps.race_id
where source_laps.laps is distinct from model_laps.laps
    or source_laps.total_ms is distinct from model_laps.total_ms
