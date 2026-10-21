{#
  Regression tooling for upstream changes (vendor migrations, refactors).

    1. Before changing anything:
         dbt run-operation clone_baseline
       Zero-copy clones every built table into <target schema>_BASELINE.
    2. Fix the project, then rebuild everything from scratch:
         dbt build --full-refresh
    3. Compare:
         dbt run-operation compare_to_baseline
       Logs row counts and row-level differences (both directions) for every
       table, ignoring load timestamps. Every line should show 0 / 0.

  Tables are transient (the dbt default on Snowflake), so the clones are too.
#}

{% macro _baseline_layers() %}
    {{ return(['marts', 'snapshots', 'reference']) }}
{% endmacro %}

{% macro _baseline_schema() %}
    {{ return((target.schema ~ '_baseline') | upper) }}
{% endmacro %}

{% macro _built_tables() %}
    {% set schemas = [] %}
    {% for layer in _baseline_layers() %}
        {% do schemas.append("'" ~ (target.schema ~ '_' ~ layer) | upper ~ "'") %}
    {% endfor %}
    {% set query %}
        select table_schema, table_name
        from {{ target.database }}.information_schema.tables
        where table_schema in ({{ schemas | join(', ') }})
            and table_type = 'BASE TABLE'
        order by table_name
    {% endset %}
    {{ return(run_query(query).rows) }}
{% endmacro %}

{% macro clone_baseline() %}
    {% set baseline = target.database ~ '.' ~ _baseline_schema() %}
    {% do run_query('create schema if not exists ' ~ baseline) %}
    {% for row in _built_tables() %}
        {% do run_query('create or replace transient table ' ~ baseline ~ '.' ~ row[1]
            ~ ' clone ' ~ target.database ~ '.' ~ row[0] ~ '.' ~ row[1]) %}
        {{ log('cloned ' ~ row[0] ~ '.' ~ row[1], info=True) }}
    {% endfor %}
{% endmacro %}

{% macro compare_to_baseline(ignore_columns=['LOADED_AT', 'LAPS_LOADED_AT', 'CHECKED_AT', 'DBT_SCD_ID', 'DBT_UPDATED_AT', 'DBT_VALID_FROM', 'DBT_VALID_TO']) %}
    {% set baseline_schema = _baseline_schema() %}
    {% set ignored = [] %}
    {% for column in ignore_columns %}
        {% do ignored.append("'" ~ column | upper ~ "'") %}
    {% endfor %}
    {% for row in _built_tables() %}
        {% set old = target.database ~ '.' ~ baseline_schema ~ '.' ~ row[1] %}
        {% set new = target.database ~ '.' ~ row[0] ~ '.' ~ row[1] %}
        {% set column_query %}
            select listagg(column_name, ', ') within group (order by ordinal_position)
            from {{ target.database }}.information_schema.columns
            where table_schema = '{{ baseline_schema }}'
                and table_name = '{{ row[1] }}'
                and column_name not in ({{ ignored | join(', ') }})
        {% endset %}
        {% set columns = run_query(column_query).columns[0].values()[0] %}
        {% if not columns %}
            {{ log('NEW TABLE (no baseline) ' ~ row[1], info=True) }}
        {% else %}
            {% set diff_query %}
                select
                    (select count(*) from {{ old }}),
                    (select count(*) from {{ new }}),
                    (select count(*) from (select {{ columns }} from {{ old }} minus select {{ columns }} from {{ new }})),
                    (select count(*) from (select {{ columns }} from {{ new }} minus select {{ columns }} from {{ old }}))
            {% endset %}
            {% set r = run_query(diff_query).rows[0] %}
            {{ log(('OK   ' if r[0] == r[1] and r[2] == 0 and r[3] == 0 else 'DIFF ') ~ row[1]
                ~ ': baseline_rows=' ~ r[0] ~ ' new_rows=' ~ r[1]
                ~ ' only_in_baseline=' ~ r[2] ~ ' only_in_new=' ~ r[3], info=True) }}
        {% endif %}
    {% endfor %}
{% endmacro %}
