{#-
  One row per vendor table: how many raw rows were re-deliveries of a natural
  key that staging collapsed. A view, so it always reflects the current feed.
  redelivered_rows > 0 means the vendor resent rows (also a build warning);
  the conflicting case fails the build via no_conflicting_duplicates.
-#}
{%- set natural_keys = {
    'circuits': ['circuitid'],
    'constructors': ['constructorid'],
    'constructor_results': ['raceid', 'constructorid'],
    'constructor_standings': ['raceid', 'constructorid'],
    'drivers': ['driverid'],
    'driver_standings': ['raceid', 'driverid'],
    'lap_times': ['raceid', 'driverid', 'lap'],
    'pit_stops': ['raceid', 'driverid', 'stop'],
    'qualifying': ['raceid', 'driverid'],
    'races': ['raceid'],
    'results': ['raceid', 'driverid', 'position_order'],
    'seasons': ['year'],
    'sprint_results': ['raceid', 'driverid'],
    'status': ['statusid'],
} -%}

{% for table, keys in natural_keys.items() %}
select
    '{{ table }}'                                       as source_table,
    '{{ keys | join(", ") }}'                           as natural_key,
    count(*)                                            as raw_rows,
    count(distinct {% for c in keys %}{{ clean_text(c) }}{{ ", " if not loop.last }}{% endfor %}) as distinct_keys,
    count(*) - count(distinct {% for c in keys %}{{ clean_text(c) }}{{ ", " if not loop.last }}{% endfor %}) as redelivered_rows
from {{ source('ergast', table) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}
