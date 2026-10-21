{#
  Drops every schema this target owns (<target schema> and
  <target schema>_<layer>) so each CI run starts empty. Leftover tables from
  an earlier pull request could otherwise shadow the production relations
  that unchanged models are deferred to. Refuses to run on any target except ci.
#}
{% macro reset_ci_schemas() %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("reset_ci_schemas only runs on the ci target (got '" ~ target.name ~ "')") }}
    {% endif %}
    {% set prefix = target.schema | upper %}
    {% set schemas = run_query(
        "select schema_name from " ~ target.database ~ ".information_schema.schemata "
        ~ "where schema_name = '" ~ prefix ~ "' or startswith(schema_name, '" ~ prefix ~ "_')"
    ).columns[0].values() %}
    {% for schema in schemas %}
        {% do run_query("drop schema if exists " ~ target.database ~ "." ~ schema ~ " cascade") %}
        {{ log("dropped " ~ schema, info=True) }}
    {% endfor %}
{% endmacro %}
