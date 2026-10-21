{#
  Default dbt behaviour (target schema + "_" + custom schema), made explicit so
  every model is guaranteed to land in a schema prefixed by the target schema
  (F1_DBT_A_1). Never builds into a bare custom schema.
#}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
