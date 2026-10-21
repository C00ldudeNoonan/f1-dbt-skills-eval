-- Live view of duplicate rows in the raw vendor feed, one row per raw table
-- and natural key. Staging keeps one copy of each duplicated key, so these
-- rows never reach the marts. The view shows how often the vendor resends
-- data. `conflicting_keys` > 0 means the copies disagree, and the build stops
-- at the source until the vendor fixes it.

{% set natural_keys = {
    'circuits': ['circuitid'],
    'constructors': ['constructorid'],
    'constructor_results': ['raceid', 'constructorid'],
    'constructor_standings': ['raceid', 'constructorid'],
    'drivers': ['driverid'],
    'driver_standings': ['raceid', 'driverid'],
    'lap_timing': ['raceid', 'driverid', 'lap'],
    'pit_stops': ['raceid', 'driverid', 'stop'],
    'qualifying': ['raceid', 'driverid'],
    'races': ['raceid'],
    'results': ['raceid', 'driverid', 'position_order'],
    'seasons': ['year'],
    'sprint_results': ['raceid', 'driverid', 'position_order'],
    'status': ['statusid'],
    'vb_drivers': ['driver_key'],
    'vb_sessions': ['session_key'],
    'vb_results': ['session_key', 'driver_key'],
} %}

{% for table, keys in natural_keys.items() %}
select
    '{{ table }}' as source_table,
    '{{ keys | join(", ") }}' as natural_key,
    (select count(*) from {{ source('f1_raw', table) }}) as raw_rows,
    count(*) as duplicated_keys,
    coalesce(sum(copies - 1), 0) as extra_rows,
    current_timestamp() as checked_at
from (
    select {{ keys | join(', ') }}, count(*) as copies
    from {{ source('f1_raw', table) }}
    group by {{ keys | join(', ') }}
    having count(*) > 1
)
{% if not loop.last %}union all{% endif %}
{% endfor %}
