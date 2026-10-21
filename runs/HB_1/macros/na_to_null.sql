{#- Ergast/Kaggle CSVs encode missing values as the literal string \N. -#}
{% macro na_to_null(column_name) -%}
    nullif(trim({{ column_name }}), '\\N')
{%- endmacro %}
