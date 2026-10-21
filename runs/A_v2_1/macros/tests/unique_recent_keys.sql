{#-
    unique_combination_of_columns restricted to rows loaded in the last
    window_days before the latest load, for very large incremental tables
    whose history is already guaranteed unique by a merge on the same key.
    Also fails on null key columns in that window.
-#}
{% test unique_recent_keys(model, combination_of_columns, loaded_at_column, window_days) %}

with recent as (

    select *
    from {{ model }}
    where {{ loaded_at_column }} >= dateadd(
        day, -{{ window_days }},
        (select max({{ loaded_at_column }}) from {{ model }})
    )

)

select
    {{ combination_of_columns | join(', ') }},
    count(*) as row_count
from recent
group by {{ combination_of_columns | join(', ') }}
having count(*) > 1
    {%- for column in combination_of_columns %}
    or {{ column }} is null
    {%- endfor %}

{% endtest %}
