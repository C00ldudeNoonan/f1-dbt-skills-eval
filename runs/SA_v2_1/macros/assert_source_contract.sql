{#- Compares every source table/column declared in the project's source yml files with what
    actually exists in the warehouse. Run automatically at the start of every dbt invocation
    (see on-run-start in dbt_project.yml) and callable on its own:
        dbt run-operation assert_source_contract
    Missing tables or columns (the vendor renamed or dropped something) stop the run with one
    readable report. New, undeclared columns are listed as warnings so they are noticed. -#}
{% macro assert_source_contract() %}
    {% if execute %}
        {% set problems = [] %}
        {% set notices = [] %}
        {% set catalog = {} %}
        {% for node in graph.sources.values() | selectattr('resource_type', 'equalto', 'source') %}
            {% if node.package_name == project_name %}
                {% set expected = node.columns.keys() | map('upper') | list %}
                {% set schema_key = node.database ~ '.' ~ node.schema %}
                {% if schema_key not in catalog %}
                    {% set result = run_query(
                        "select table_name, column_name from " ~ node.database ~ ".information_schema.columns"
                        ~ " where table_schema = upper('" ~ node.schema ~ "')"
                    ) %}
                    {% do catalog.update({schema_key: result.rows}) %}
                {% endif %}
                {% set table_name = (node.identifier or node.name) | upper %}
                {% set found = [] %}
                {% for row in catalog[schema_key] %}
                    {% if row[0] | upper == table_name %}{% do found.append(row[1] | upper) %}{% endif %}
                {% endfor %}
                {% set label = node.database ~ '.' ~ node.schema ~ '.' ~ (node.identifier or node.name) %}
                {% if found | length == 0 %}
                    {% do problems.append('TABLE MISSING: ' ~ label ~ ' (was it renamed or dropped?)') %}
                {% else %}
                    {% set missing = expected | reject('in', found) | list %}
                    {% set extra = found | reject('in', expected) | list %}
                    {% if missing %}
                        {% do problems.append('COLUMNS MISSING in ' ~ label ~ ': ' ~ missing | join(', ')) %}
                    {% endif %}
                    {% if extra %}
                        {% do notices.append('NEW UNDECLARED COLUMNS in ' ~ label ~ ': ' ~ extra | join(', ')) %}
                    {% endif %}
                {% endif %}
            {% endif %}
        {% endfor %}
        {% for n in notices %}{% do log('SOURCE CONTRACT WARNING: ' ~ n, info=True) %}{% endfor %}
        {% if problems %}
            {{ exceptions.raise_compiler_error(
                "\n\nSOURCE CONTRACT BROKEN - the vendor changed the raw schema:\n  - "
                ~ problems | join("\n  - ")
                ~ "\n\nUpdate models/staging/ergast/_ergast__sources.yml and the staging models, then re-run."
            ) }}
        {% endif %}
    {% endif %}
{% endmacro %}
