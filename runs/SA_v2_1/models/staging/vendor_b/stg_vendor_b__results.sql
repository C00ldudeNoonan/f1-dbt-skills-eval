-- position is a number for classified finishers and DNF / DSQ otherwise.
select distinct
    session_key::integer as session_key,
    {{ clean_text('driver_key') }} as driver_key,
    {{ clean_text('team_name') }} as team_name,
    grid_position::integer as grid,
    {{ clean_text('position') }} as position_raw,
    try_to_number({{ clean_text('position') }}) as finish_position,
    points::number(8, 2) as points
from {{ source('vendor_b', 'vb_results') }}
