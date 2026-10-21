{#
    One row per Grand Prix result entry. Sprints are excluded (they live in SPRINT_RESULTS).

    finish_position is the classified finishing place. It is null for retirements and
    disqualifications. The raw POSITION column is null for two lapped finishers in 2005,
    but their POSITIONTEXT holds a real place, so that place is used when it is numeric.
#}
with results as (

    select * from {{ ref('stg_f1__results') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

constructors as (

    select * from {{ ref('stg_f1__constructors') }}

),

status as (

    select * from {{ ref('stg_f1__status') }}

),

classified as (

    select
        results.*,
        {{ classified_finish_position('results.position', 'results.position_text') }} as finish_position
    from results

)

select
    classified.result_id,
    classified.race_id,
    races.season,
    races.round,
    races.race_date,
    classified.driver_id,
    classified.constructor_id,
    constructors.constructor_name,
    classified.grid,
    classified.finish_position,
    classified.position_order,
    classified.points,
    classified.laps,
    status.status_name as status,
    coalesce(classified.finish_position = 1, false) as is_win,
    coalesce(classified.finish_position <= 3, false) as is_podium,
    classified.fastest_lap_time_ms
from classified
left join races
    on classified.race_id = races.race_id
left join constructors
    on classified.constructor_id = constructors.constructor_id
left join status
    on classified.status_id = status.status_id
