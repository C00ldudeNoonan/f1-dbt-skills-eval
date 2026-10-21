{#-
    Drops every schema belonging to the ci target (its base schema and all
    custom-schema suffixes, e.g. F1_DBT_A_v2_1_CI_STAGING) so each CI run starts
    clean. Without this, deferral would prefer stale relations left by an
    earlier CI run over production. Refuses to run on any target but ci.
-#}
{% macro drop_ci_schemas() %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas only runs on the ci target (got '" ~ target.name ~ "')") }}
    {% endif %}
    {% set base = target.schema | upper %}
    {% set found = run_query(
        "select schema_name from " ~ target.database ~ ".information_schema.schemata"
        ~ " where schema_name = '" ~ base ~ "' or schema_name like '" ~ base ~ "\\\\_%' escape '\\\\'"
    ) %}
    {% for row in found.rows %}
        {% do run_query("drop schema if exists " ~ target.database ~ "." ~ row[0] ~ " cascade") %}
        {{ print("dropped " ~ target.database ~ "." ~ row[0]) }}
    {% endfor %}
{% endmacro %}
