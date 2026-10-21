{#
    Vendor B result entries, one per session and driver. position_text is kept as the feed sends it (DNF, DSQ, or a
    number). position is set only for classified finishers, so unclassified entries are NULL.
#}
select
    SESSION_KEY::varchar as session_key,
    trim(DRIVER_KEY) as driver_key,
    trim(TEAM_NAME) as team_name,
    {{ null_if_sentinel('GRID_POSITION') }}::integer as grid_position,
    upper(trim(POSITION)) as position_text,
    case when regexp_like(trim(POSITION), '^[0-9]+$') then trim(POSITION)::integer end as position,
    POINTS::numeric(6, 2) as points
from {{ source('vendor_b', 'VB_RESULTS') }}
