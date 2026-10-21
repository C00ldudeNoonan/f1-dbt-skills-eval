{% test source_has_columns(model, columns) %}
{#- Fails with one row per expected column missing from the source table, so a vendor
    rename/drop shows up as a clear "table.column is missing" instead of an invalid-identifier
    error deep in a staging model. Attach to source tables: it then runs before staging. -#}
with expected as (
    {% for column in columns %}
    select '{{ column | upper }}' as column_name {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

actual as (
    select column_name
    from {{ model.database }}.information_schema.columns
    where table_schema = upper('{{ model.schema }}')
      and table_name = upper('{{ model.identifier }}')
)

select
    '{{ model.identifier }}' as source_table,
    expected.column_name as missing_column
from expected
left join actual using (column_name)
where actual.column_name is null
{% endtest %}
