{#
    Standard dbt behaviour (<target_schema>_<custom_schema>), made explicit so
    the convention is visible and stable: every relation lands in a schema
    prefixed with the target schema (F1_DBT_B_1 in dev).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
