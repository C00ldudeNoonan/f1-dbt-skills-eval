-- Grain: one row per driver per lap per race.
-- Incremental by race. The timing provider can reissue corrected laps for either of the two most
-- recent races already loaded, so each run reprocesses (a) every race newer than the loaded ones and
-- (b) the two latest loaded races, replacing those races wholesale (delete+insert on race_id).
-- Recency is by calendar order (season, round), not race_id. Older races change only via --full-refresh.
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

select
    laps.race_id,
    races.season,
    races.round,
    laps.driver_id,
    laps.lap,
    laps.position,
    laps.lap_time_ms
from {{ ref('stg_f1__lap_times') }} as laps
inner join {{ ref('stg_f1__races') }} as races on races.race_id = laps.race_id
{% if is_incremental() %}
where races.season * 100 + races.round >= (
    -- start of the reprocessing window: the second most recent race already loaded
    select min(race_seq)
    from (
        select season * 100 + round as race_seq
        from {{ this }}
        group by 1
        qualify row_number() over (order by race_seq desc) <= 2
    )
)
{% endif %}
