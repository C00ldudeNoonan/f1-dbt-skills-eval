-- Sprint session results (2021 onwards). Note: result_id here is a separate id space from
-- results.result_id and overlaps it, so it is only unique together with the session type.
select distinct
    resultid::integer as result_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    constructorid::integer as constructor_id,
    statusid::integer as status_id,
    {{ clean_text('grid') }}::integer as grid,
    coalesce(
        {{ clean_text('position') }},
        case when regexp_like(trim(positiontext), '[0-9]+') then trim(positiontext) end
    )::integer as finish_position,
    {{ clean_text('position_order') }}::integer as position_order,
    {{ clean_text('points') }}::number(8, 2) as points,
    {{ clean_text('laps') }}::integer as laps
from {{ source('ergast', 'sprint_results') }}
