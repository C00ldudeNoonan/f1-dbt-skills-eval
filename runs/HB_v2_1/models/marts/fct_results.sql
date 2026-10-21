{#
    Grand Prix race results, one row per result entry (result_id).
    Sprint results are not included. Grain check: a driver can appear more than
    once in a race before 1979 (two cars entered), so the unique key is result_id.
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
        -- The finishing position is in POSITION, except for a handful of
        -- classified finishers (lapped cars) where POSITION is \N but
        -- POSITIONTEXT holds the number. Non-numeric POSITIONTEXT means not classified.
        coalesce(
            results.position,
            {{ position_text_to_int('results.position_text') }}
        ) as finish_position

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
    status.status,
    classified.status_id,
    classified.finish_position is not null as is_classified,
    coalesce(classified.finish_position = 1, false) as is_win,
    coalesce(classified.finish_position <= 3, false) as is_podium,
    classified.fastest_lap_time_ms,
    classified.race_time_ms

from classified
inner join races
    on classified.race_id = races.race_id
left join constructors
    on classified.constructor_id = constructors.constructor_id
left join status
    on classified.status_id = status.status_id
