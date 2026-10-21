-- One row per Grand Prix classification entry. Sprint results are not included: the
-- source `results` table only holds Grands Prix.
with results as (

    select * from {{ ref('stg_ergast__results') }}

),

races as (

    select * from {{ ref('stg_ergast__races') }}

),

constructors as (

    select * from {{ ref('stg_ergast__constructors') }}

),

status as (

    select * from {{ ref('stg_ergast__status') }}

)

select
    results.result_id,
    results.race_id,
    races.season,
    races.round,
    races.race_name,
    races.race_date,
    results.driver_id,
    results.constructor_id,
    constructors.constructor_name,
    results.grid,
    results.finish_position,
    results.finish_position_text,
    results.position_order,
    results.points,
    results.laps,
    status.status,
    -- Did not qualify / did not prequalify / withdrew entries never took the start.
    status.status not in ('Did not qualify', 'Did not prequalify', 'Withdrew') as is_race_start,
    coalesce(results.finish_position = 1, false) as is_win,
    coalesce(results.finish_position between 1 and 3, false) as is_podium,
    results.fastest_lap_time_ms

from results
inner join races
    on results.race_id = races.race_id
inner join constructors
    on results.constructor_id = constructors.constructor_id
inner join status
    on results.status_id = status.status_id
