{#-
  Drop every schema belonging to the current target (e.g. F1_DBT_B_v2_1_CI and
  F1_DBT_B_v2_1_CI_marts). scripts/ci.sh runs it before each CI build so no
  stale relation from an earlier CI run can shadow prod during deferral.
  Refuses to run for any target other than ci.
-#}
{% macro drop_target_schemas() %}
    {% if target.name != 'ci' or not (target.schema | upper).endswith('_CI') %}
        {{ exceptions.raise_compiler_error("drop_target_schemas only runs against the ci target (got target '" ~ target.name ~ "', schema '" ~ target.schema ~ "')") }}
    {% endif %}
    {% set prefix = target.schema | upper %}
    {% set schemas = run_query("show terse schemas in database " ~ target.database) %}
    {% for row in schemas.rows %}
        {% set name = row['name'] | upper %}
        {% if name == prefix or name.startswith(prefix ~ '_') %}
            {% do run_query("drop schema if exists " ~ target.database ~ "." ~ name ~ " cascade") %}
            {% do log("dropped " ~ name, info=true) %}
        {% endif %}
    {% endfor %}
{% endmacro %}

{#-
  One-time prod bootstrap: start the prod snapshot from dev's existing history
  (zero-copy clone) so prod's snp_drivers isn't empty. Only runs for prod, and
  only when the prod snapshot doesn't exist yet.
-#}
{% macro bootstrap_prod_snapshots(from_schema) %}
    {% if target.name != 'prod' %}
        {{ exceptions.raise_compiler_error("bootstrap_prod_snapshots only runs against the prod target") }}
    {% endif %}
    {% set dest = target.database ~ "." ~ target.schema ~ "_snapshots" %}
    {% set existing = run_query("show terse tables like 'SNP_DRIVERS' in database " ~ target.database) %}
    {% for row in existing.rows %}
        {% if row['schema_name'] | upper == (target.schema ~ '_snapshots') | upper %}
            {% do log(dest ~ ".snp_drivers already exists; nothing to do", info=true) %}
            {{ return('') }}
        {% endif %}
    {% endfor %}
    {% do run_query("create schema if not exists " ~ dest) %}
    {% do run_query("create transient table " ~ dest ~ ".snp_drivers clone " ~ target.database ~ "." ~ from_schema ~ ".snp_drivers") %}
    {% do log("cloned " ~ from_schema ~ ".snp_drivers into " ~ dest, info=true) %}
{% endmacro %}
