{#
    Compares every table and snapshot in this project with a baseline copy of it in another schema, row by row.
    Use it to prove a change did not move any numbers, for example after a vendor migration:

        dbt run-operation compare_to_baseline --args '{baseline_schema: F1_DBT_HC_V2_1_PRE_MIGRATION}'

    For each model that is a table, incremental model or snapshot, and has a same-named table in baseline_schema,
    it reports the row counts and the rows that differ in either direction (EXCEPT, all columns). It fails if any
    table differs, so the difference is never buried in build output. Views are skipped, and so are models with no
    baseline table. Those are listed so nothing is skipped silently.

    Make the baseline by cloning the tables before the change, e.g.
        create transient table <baseline_schema>.<name> clone <schema>.<name>
    Clones are zero-copy, so this costs almost nothing.
#}
{% macro compare_to_baseline(baseline_schema, fail_on_difference=true) %}
    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set db = target.database %}
    {% set differing = [] %}
    {% set compared = [] %}
    {% set skipped = [] %}

    {% for node in graph.nodes.values() %}
        {% set is_table = (node.resource_type == 'snapshot') or (node.resource_type == 'model' and node.config.materialized in ['table', 'incremental']) %}
        {% if is_table and node.resource_type in ['model', 'snapshot'] %}
            {% set name = node.alias | upper %}
            {% set baseline_rows = run_query("show tables like '" ~ name ~ "' in schema " ~ db ~ "." ~ baseline_schema).rows %}
            {% if baseline_rows | length == 0 %}
                {% do skipped.append(name ~ " (no baseline table)") %}
            {% else %}
                {% set cur = db ~ "." ~ node.schema ~ "." ~ name %}
                {% set base = db ~ "." ~ baseline_schema ~ "." ~ name %}
                {% set cur_cols = run_query("select * from " ~ cur ~ " limit 0").columns | map(attribute='name') | map('upper') | sort | list %}
                {% set base_cols = run_query("select * from " ~ base ~ " limit 0").columns | map(attribute='name') | map('upper') | sort | list %}
                {% set counts = run_query("select (select count(*) from " ~ base ~ "), (select count(*) from " ~ cur ~ ")").rows[0] %}
                {% if cur_cols != base_cols %}
                    {% do differing.append(name ~ ": columns differ (baseline " ~ base_cols | length ~ ", now " ~ cur_cols | length ~ ")") %}
                {% else %}
                    {% set diff = run_query("select (select count(*) from (select * from " ~ base ~ " except select * from " ~ cur ~ ")), (select count(*) from (select * from " ~ cur ~ " except select * from " ~ base ~ "))").rows[0] %}
                    {% if diff[0] > 0 or diff[1] > 0 or counts[0] != counts[1] %}
                        {% do differing.append(name ~ ": rows " ~ counts[0] ~ " -> " ~ counts[1] ~ ", only in baseline " ~ diff[0] ~ ", only in now " ~ diff[1]) %}
                    {% endif %}
                {% endif %}
                {% do compared.append(name) %}
            {% endif %}
        {% endif %}
    {% endfor %}

    {{ log("compared " ~ compared | length ~ " tables against " ~ baseline_schema ~ ": " ~ compared | join(', '), info=True) }}
    {% for s in skipped %}{{ log("skipped " ~ s, info=True) }}{% endfor %}
    {% if differing | length == 0 %}
        {{ log("NO DIFFERENCES: every compared table matches its baseline row for row.", info=True) }}
    {% else %}
        {% for d in differing %}{{ log("DIFFERENT " ~ d, info=True) }}{% endfor %}
        {% if fail_on_difference %}
            {{ exceptions.raise_compiler_error(differing | length ~ " table(s) differ from " ~ baseline_schema ~ ". See the DIFFERENT lines above.") }}
        {% endif %}
    {% endif %}
{% endmacro %}
