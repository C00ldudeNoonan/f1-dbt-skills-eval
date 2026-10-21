{#-
  Vendor schema guard, run on-run-start (see dbt_project.yml).

  Compares every table and column declared in the project's sources against
  what actually exists in the warehouse, before any model, snapshot or
  incremental table is touched.
    - A declared table or column that is missing: the run stops with a list.
      (Renames show up as one missing column/table plus one new one.)
    - A column that exists but isn't declared: a warning, so additions are
      noticed and documented, but don't block the run.
  Bypass in an emergency with --vars '{skip_source_schema_check: true}'.
-#}
{% macro check_source_schemas() %}
    {% if not execute or var('skip_source_schema_check', false) %}
        {{ return('') }}
    {% endif %}

    {%- set declared = {} -%}
    {%- for node in graph.sources.values() if node.package_name == project_name -%}
        {%- set location = (node.database ~ '.' ~ node.schema) | upper -%}
        {%- do declared.setdefault(location, {}) -%}
        {%- do declared[location].update({
            (node.identifier | upper): {
                'source': node.source_name ~ '.' ~ node.name,
                'columns': node.columns.keys() | map('upper') | list
            }
        }) -%}
    {%- endfor -%}

    {%- set problems = [] -%}
    {%- set additions = [] -%}
    {%- for location, tables in declared.items() -%}
        {%- set result = run_query('show columns in schema ' ~ location) -%}
        {%- set actual = {} -%}
        {%- for row in result.rows -%}
            {%- do actual.setdefault(row['table_name'] | upper, []).append(row['column_name'] | upper) -%}
        {%- endfor -%}

        {%- for table, spec in tables.items() -%}
            {%- if table not in actual -%}
                {%- do problems.append('missing table ' ~ location ~ '.' ~ table ~ ' (source ' ~ spec.source ~ ')') -%}
            {%- else -%}
                {%- for column in spec.columns if column not in actual[table] -%}
                    {%- do problems.append('missing column ' ~ table ~ '.' ~ column ~ ' (source ' ~ spec.source ~ ')') -%}
                {%- endfor -%}
                {%- for column in actual[table] if spec.columns and column not in spec.columns -%}
                    {%- do additions.append(table ~ '.' ~ column) -%}
                {%- endfor -%}
            {%- endif -%}
        {%- endfor -%}
        {%- for table in actual.keys() if table not in tables -%}
            {%- do additions.append(location ~ '.' ~ table ~ ' (whole table)') -%}
        {%- endfor -%}
    {%- endfor -%}

    {%- if additions -%}
        {% do exceptions.warn(
            'VENDOR SCHEMA CHANGE: columns/tables exist but are not declared in sources: '
            ~ additions | join(', ')
            ~ '. Declare them in models/staging/ergast/_ergast__sources.yml.'
        ) %}
    {%- endif -%}
    {%- if problems -%}
        {{ exceptions.raise_compiler_error(
            'VENDOR SCHEMA CHANGE DETECTED. Nothing was built. The raw data no longer matches '
            ~ 'the declared sources:\n  - ' ~ problems | join('\n  - ')
            ~ '\nUndeclared columns/tables present: ' ~ (additions | join(', ') or 'none')
            ~ '\nFix models/staging/ergast/_ergast__sources.yml and the staging models, then rerun. '
            ~ 'See "Vendor changes" in README.md.'
        ) }}
    {%- endif -%}
    {% do log('Source schema check passed: all declared source tables and columns exist.', info=true) %}
{% endmacro %}
