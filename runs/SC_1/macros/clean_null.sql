{#- The raw Ergast/Kaggle load keeps the CSV null marker `\N` as literal text. -#}
{% macro clean_null(column_name) -%}
    nullif({{ column_name }}, '\\N')
{%- endmacro %}
