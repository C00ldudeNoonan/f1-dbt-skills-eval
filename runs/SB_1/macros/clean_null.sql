{#- The Ergast/Kaggle CSVs encode NULL as the literal two-character string \N.
    Raw columns are all text, so every staging model funnels columns through here. -#}
{% macro clean_null(column) -%}
    nullif(trim({{ column }}), '\\N')
{%- endmacro %}
