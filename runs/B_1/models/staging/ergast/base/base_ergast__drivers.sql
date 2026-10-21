{#
    Raw drivers columns as-is (untyped, untrimmed), with repeated vendor loads
    removed: rows that are identical after trimming whitespace collapse to one
    (the shortest raw version). Exists only so snp_drivers can snapshot the
    vendor data without a duplicate load creating duplicate history. Rows
    with the same driverid but genuinely different values are kept and fail
    the unique test, which blocks the snapshot.
#}

{% set raw_columns = ['driverid', 'driverref', 'number', 'code', 'forename', 'surname', 'dob', 'nationality', 'url'] %}

with source as (
    select * from {{ source('ergast', 'drivers') }}
)

select {{ raw_columns | join(', ') }}
from source
qualify row_number() over (
    partition by
        {% for col in raw_columns %}trim({{ col }}){% if not loop.last %}, {% endif %}{% endfor %}
    order by
        {% for col in raw_columns %}length({{ col }}){% if not loop.last %} + {% endif %}{% endfor %}
) = 1
