{#-
    Fails for every raw value that is present (not \N or empty) but that the
    staging parser for its type turns into null: the signature of a vendor
    format change. Uses the exact macros staging uses (parse_as), so a pass
    means staging loses no values.

    columns: mapping of raw column name -> type (int, decimal, date, time, duration).
    Returns one row per failing column and distinct value, with a count.
-#}
{% test values_parse(model, columns) %}

{% for column, type in columns.items() %}
select
    '{{ column }}' as column_name,
    '{{ type }}' as expected_type,
    {{ clean_text(column) }} as raw_value,
    count(*) as failing_rows
from {{ model }}
where {{ clean_text(column) }} is not null
    and ({{ parse_as(column, type) }}) is null
group by 1, 2, 3
{% if not loop.last %}union all{% endif %}
{% endfor %}

{% endtest %}
