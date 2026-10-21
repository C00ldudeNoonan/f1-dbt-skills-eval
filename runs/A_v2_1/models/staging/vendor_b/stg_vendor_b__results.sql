-- Vendor B results. finish_position is the classified position; text values
-- such as DNF and DSQ mean not classified.
select
    session_key::integer as session_key,
    {{ clean_text('driver_key') }} as driver_key,
    {{ clean_text('team_name') }} as team_name,
    grid_position::integer as grid,
    {{ clean_text('position') }} as position_text,
    {{ to_int('position') }} as finish_position,
    points::number(8, 2) as points
from {{ source('vendor_b', 'vb_results') }}
{{ dedupe_on(['session_key', 'driver_key'], 'driver_key') }}
