{#-
    One row per driver per stint, for races that have pit stop data.

    Stint 1 starts on lap 1. A pit stop on lap L ends the current stint at lap L
    and the next stint starts on lap L + 1. The final stint ends on the driver's
    last recorded lap. Stints with no laps (for example after a pit stop on the
    final lap) are dropped. stint_number is 1 + the number of the driver's pit
    stops before the stint, so it matches the stop sequence.

    Incremental, delete+insert by race. A race is rebuilt when:
      * fct_lap_times (re)loaded it after this table last saw it (new race or
        lap correction), or
      * it has pit stop data but no stints here yet (pit data arrived late).
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

with pit_stops as (

    select race_id, driver_id, lap as pit_lap
    from {{ ref('stg_ergast__pit_stops') }}

),

races_with_pit_data as (

    select distinct race_id from pit_stops

),

laps as (

    select laps.*
    from {{ ref('fct_lap_times') }} as laps
    inner join races_with_pit_data
        on laps.race_id = races_with_pit_data.race_id

    {% if is_incremental() %}
    where laps.race_id in (
        select race_id
        from {{ ref('fct_lap_times') }}
        group by race_id
        having max(dbt_updated_at) > coalesce(
            (select max(source_updated_at) from {{ this }}),
            '1900-01-01'::timestamp_ntz
        )

        union

        select race_id
        from races_with_pit_data
        where race_id not in (select race_id from {{ this }})
    )
    {% endif %}

),

laps_with_stint as (

    select
        laps.race_id,
        laps.driver_id,
        laps.lap,
        laps.lap_time_ms,
        laps.dbt_updated_at,
        1 + count(pit_stops.pit_lap) as stint_number
    from laps
    left join pit_stops
        on laps.race_id = pit_stops.race_id
        and laps.driver_id = pit_stops.driver_id
        and pit_stops.pit_lap < laps.lap
    group by 1, 2, 3, 4, 5

)

select
    race_id,
    driver_id,
    stint_number,
    min(lap) as start_lap,
    max(lap) as end_lap,
    count(*) as stint_laps,
    avg(lap_time_ms) as avg_lap_time_ms,
    max(dbt_updated_at) as source_updated_at
from laps_with_stint
group by race_id, driver_id, stint_number
