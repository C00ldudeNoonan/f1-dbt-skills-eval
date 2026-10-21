{#- Contract tests for raw tables. The expected column list is whatever the source YAML declares
    under `columns:`. A vendor-side rename shows up as one missing (error) plus one unexpected
    (warn) column, so the failure message points straight at the change. -#}

{% macro _declared_source_columns(model) %}
    {%- set declared = [] -%}
    {%- for node in graph.sources.values() if node.database | upper == model.database | upper
            and node.schema | upper == model.schema | upper
            and node.identifier | upper == model.identifier | upper -%}
        {%- for col in node.columns.values() -%}
            {%- do declared.append(col.name | upper) -%}
        {%- endfor -%}
    {%- endfor -%}
    {{ return(declared) }}
{% endmacro %}

{% macro _contract_sql(model, flag_missing) %}
    {%- set declared = _declared_source_columns(model) -%}
    with expected as (
        select column_name
        from (values {% for c in declared %}('{{ c }}'){{ ',' if not loop.last }}{% endfor %}) as t (column_name)
    ),

    actual as (
        select column_name
        from {{ model.database }}.information_schema.columns
        where table_schema = upper('{{ model.schema }}')
            and table_name = upper('{{ model.identifier }}')
    )

    {% if flag_missing %}
    select expected.column_name as missing_column
    from expected
    left join actual using (column_name)
    where actual.column_name is null
    {% else %}
    select actual.column_name as unexpected_column
    from actual
    left join expected using (column_name)
    where expected.column_name is null
    {% endif %}
{% endmacro %}

{% test source_columns_missing(model) %}
    {{ _contract_sql(model, true) }}
{% endtest %}

{% test source_columns_unexpected(model) %}
    {{ config(severity='warn') }}
    {{ _contract_sql(model, false) }}
{% endtest %}

{#- Fails when one key maps to rows whose listed columns differ after trimming. Duplicates that are
    equal once trimmed (e.g. 'Ferrari' and 'Ferrari ') are tolerated, because staging trims and
    collapses them; genuinely conflicting ones cannot be resolved safely and must stop the build. -#}
{% test source_no_conflicting_duplicates(model, key_column, compare_columns) %}
    select {{ key_column }}
    from {{ model }}
    group by {{ key_column }}
    having count(*) > 1 and (
        {% for c in compare_columns -%}
        count(distinct trim({{ c }})) > 1{{ ' or' if not loop.last }}
        {% endfor %}
    )
{% endtest %}
