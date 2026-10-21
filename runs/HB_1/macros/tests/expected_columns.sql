{#-
    Schema contract for a source table. Fails with one row per column that is missing from the source
    or present in the source but not listed here. Update the contract in the sources file when the
    vendor changes a schema on purpose.
-#}
{% test expected_columns(model, columns) %}

with actual as (

    select upper(column_name) as column_name
    from {{ model.database }}.information_schema.columns
    where upper(table_schema) = upper('{{ model.schema }}')
        and upper(table_name) = upper('{{ model.identifier }}')

),

expected as (

    {% for column_name in columns %}
    select '{{ column_name | upper }}' as column_name{{ ' union all' if not loop.last }}
    {% endfor %}

)

select 'missing from source' as problem, expected.column_name
from expected
where expected.column_name not in (select column_name from actual)

union all

select 'not in contract' as problem, actual.column_name
from actual
where actual.column_name not in (select column_name from expected)

{% endtest %}
