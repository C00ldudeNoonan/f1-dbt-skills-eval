-- One row per Grand Prix result entry. Sprint results are deliberately excluded.
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

-- Explicit casts: this model has an enforced contract and is consumed by
-- other projects, so column types must not drift with upstream expressions.
select
    results.result_id::integer as result_id,
    results.race_id::integer as race_id,
    races.season::integer as season,
    races.round::integer as round,
    races.race_date::date as race_date,
    races.race_name::varchar as race_name,
    races.circuit_id::integer as circuit_id,
    results.driver_id::integer as driver_id,
    results.constructor_id::integer as constructor_id,
    constructors.constructor_name::varchar as constructor_name,
    results.car_number::integer as car_number,
    results.grid::integer as grid,
    results.finish_position::integer as finish_position,
    results.position_text::varchar as position_text,
    results.position_order::integer as position_order,
    results.points::number(8, 2) as points,
    results.laps::integer as laps,
    results.status_id::integer as status_id,
    status.status::varchar as status,
    (results.finish_position is not null)::boolean as is_classified,
    coalesce(results.finish_position = 1, false)::boolean as is_win,
    coalesce(results.finish_position <= 3, false)::boolean as is_podium,
    results.race_time_ms::integer as race_time_ms,
    results.fastest_lap_number::integer as fastest_lap_number,
    results.fastest_lap_rank::integer as fastest_lap_rank,
    results.fastest_lap_time_ms::integer as fastest_lap_time_ms,
    results.fastest_lap_speed_kph::number(8, 3) as fastest_lap_speed_kph
from results
inner join races
    on results.race_id = races.race_id
inner join constructors
    on results.constructor_id = constructors.constructor_id
inner join status
    on results.status_id = status.status_id
