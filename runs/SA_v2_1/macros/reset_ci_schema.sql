{#- Drops and recreates the CI schema so every CI run starts clean (stale objects from an earlier
    run can never mask a failure). Refuses to run against any target other than `ci`. -#}
{% macro reset_ci_schema() %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("reset_ci_schema only runs against the ci target (got '" ~ target.name ~ "')") }}
    {% endif %}
    {% do run_query('drop schema if exists ' ~ target.database ~ '.' ~ target.schema ~ ' cascade') %}
    {% do run_query('create schema ' ~ target.database ~ '.' ~ target.schema) %}
    {% do log('CI schema ' ~ target.database ~ '.' ~ target.schema ~ ' reset', info=True) %}
{% endmacro %}
