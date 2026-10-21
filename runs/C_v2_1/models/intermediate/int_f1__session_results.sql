-- Grand Prix and sprint results in one shape, enriched once. fct_results is
-- the Grand Prix slice of this model and fct_session_results is all of it,
-- so the two can't drift apart.

with grand_prix_results as (
    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        car_number,
        grid,
        position_text,
        finish_position,
        position_order,
        points,
        laps,
        race_time_ms,
        fastest_lap_number,
        fastest_lap_rank,
        fastest_lap_time_ms,
        status_id
    from {{ ref('stg_f1__results') }}
),

sprint_results as (
    select
        'sprint' as session_type,
        result_id as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        car_number,
        grid,
        position_text,
        finish_position,
        position_order,
        points,
        laps,
        race_time_ms,
        fastest_lap_number,
        null::integer as fastest_lap_rank,
        fastest_lap_time_ms,
        status_id
    from {{ ref('stg_f1__sprint_results') }}
),

session_results as (
    select * from grand_prix_results
    union all
    select * from sprint_results
),

races as (
    select * from {{ ref('int_f1__race_calendar') }}
),

constructors as (
    select * from {{ ref('stg_f1__constructors') }}
),

status as (
    select * from {{ ref('stg_f1__status') }}
)

select
    session_results.session_type,
    session_results.source_result_id,
    session_results.race_id,
    races.season,
    races.round,
    races.race_date,
    session_results.driver_id,
    session_results.constructor_id,
    constructors.constructor_name,
    session_results.car_number,
    session_results.grid,
    session_results.position_text,
    session_results.finish_position,
    session_results.position_order,
    session_results.points,
    session_results.laps,
    status.status,
    coalesce(session_results.finish_position = 1, false) as is_win,
    coalesce(session_results.finish_position <= 3, false) as is_podium,
    session_results.race_time_ms,
    session_results.fastest_lap_number,
    session_results.fastest_lap_rank,
    session_results.fastest_lap_time_ms
from session_results
inner join races
    on session_results.race_id = races.race_id
left join constructors
    on session_results.constructor_id = constructors.constructor_id
left join status
    on session_results.status_id = status.status_id
