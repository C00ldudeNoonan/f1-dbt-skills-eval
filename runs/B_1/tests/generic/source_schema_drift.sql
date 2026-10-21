{#
    Schema-drift guards for vendor-loaded sources. Both compare the live
    columns in information_schema with the columns declared for the source
    table in YAML (the contract with the vendor), so a vendor change
    surfaces as a readable test failure on the source *before* any staging
    model runs, instead of a cryptic SQL error further down the DAG.

    declared_columns_exist   (error) a declared column is missing, i.e.
                             renamed or dropped, or its data_type changed.
    no_undeclared_columns    (warn)  the vendor added or renamed a column we
                             don't know about. Harmless until reviewed.

    Failing rows are stored (store_failures) in the <target>_dbt_test__audit
    schema, so the exact drift can be queried after a failed run.

    Pass the source's name and table name (plain strings, so tests don't fan
    out extra dependencies). The source must declare its columns.
#}

{% macro _declared_source_columns(source_name, table_name) %}
    {% set ns = namespace(columns=none) %}
    {% for node in graph.sources.values() %}
        {% if node.source_name == source_name and node.name == table_name %}
            {% set ns.columns = node.columns.values() | list %}
        {% endif %}
    {% endfor %}
    {% if execute and not ns.columns %}
        {{ exceptions.raise_compiler_error(
            "Source " ~ source_name ~ "." ~ table_name ~ " declares no columns; schema drift tests need them.") }}
    {% endif %}
    {{ return(ns.columns or []) }}
{% endmacro %}

{% macro _actual_source_columns_sql(model) %}
    select upper(column_name) as column_name, upper(data_type) as data_type
    from {{ model.database }}.information_schema.columns
    where table_schema = upper('{{ model.schema }}')
      and table_name = upper('{{ model.identifier }}')
{% endmacro %}

{% test declared_columns_exist(model, source_name, table_name) %}
    {{ config(store_failures=true) }}
    {% set declared = _declared_source_columns(source_name, table_name) %}

    with declared as (
        {% for col in declared %}
        select
            upper('{{ col.name }}') as column_name,
            {% if col.data_type %} upper('{{ col.data_type }}') {% else %} null {% endif %} as data_type
        {% if not loop.last %}union all{% endif %}
        {% endfor %}
    ),

    actual as (
        {{ _actual_source_columns_sql(model) }}
    )

    select
        '{{ source_name }}.{{ table_name }}' as source_table,
        declared.column_name,
        declared.data_type as declared_type,
        actual.data_type as actual_type,
        iff(actual.column_name is null,
            'declared column missing from source (renamed or dropped by vendor?)',
            'data type changed') as issue
    from declared
    left join actual
        on declared.column_name = actual.column_name
    where actual.column_name is null
       or (declared.data_type is not null and declared.data_type != actual.data_type)
{% endtest %}

{% test no_undeclared_columns(model, source_name, table_name) %}
    {{ config(severity='warn', store_failures=true) }}
    {% set declared = _declared_source_columns(source_name, table_name) %}

    with declared as (
        {% for col in declared %}
        select upper('{{ col.name }}') as column_name
        {% if not loop.last %}union all{% endif %}
        {% endfor %}
    ),

    actual as (
        {{ _actual_source_columns_sql(model) }}
    )

    select
        '{{ source_name }}.{{ table_name }}' as source_table,
        actual.column_name,
        'column in source but not declared in _ergast__sources.yml (new or renamed by vendor?)' as issue
    from actual
    left join declared
        on actual.column_name = declared.column_name
    where declared.column_name is null
{% endtest %}
