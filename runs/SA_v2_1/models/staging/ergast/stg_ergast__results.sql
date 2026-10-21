-- Grand Prix results only; sprint results live in their own source table.
-- `position` is null for unclassified entries (retirements, DSQ, ...), but a handful
-- of lapped finishers (e.g. 2005 Australian GP) also have a null `position` while
-- `positiontext` holds their classified place, so we fall back to it.
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
    {{ clean_text('laps') }}::integer as laps,
    {{ lap_time_to_ms('fastestlaptime') }} as fastest_lap_time_ms
from {{ source('ergast', 'results') }}
