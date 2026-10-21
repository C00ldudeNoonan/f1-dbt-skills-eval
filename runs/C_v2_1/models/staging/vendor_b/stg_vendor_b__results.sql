-- Vendor B results, one row per driver per session. POSITION is a number for
-- classified finishers, or DNF / DSQ.

with source as (
    select * from {{ source('f1_raw', 'vb_results') }}
)

select
    session_key,
    {{ clean_text('driver_key') }} as driver_key,
    {{ clean_text('team_name') }} as team_name,
    grid_position as grid,
    {{ clean_text('position') }} as position_text,
    {{ to_integer('position') }} as finish_position,
    points::number(8, 2) as points
from source
{{ deduplicate('session_key, driver_key', 'session_key') }}
