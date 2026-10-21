{#- The Ergast CSV extracts write missing values as the literal two-character string \N. -#}
{% macro null_if_sentinel(column_name) %}
    nullif(trim({{ column_name }}), '\\N')
{% endmacro %}
