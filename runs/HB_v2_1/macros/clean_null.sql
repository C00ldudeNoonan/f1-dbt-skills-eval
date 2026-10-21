{#
    Converts the raw missing-value markers to NULL: the literal string \N (results, races,
    drivers) and the empty string (qualifying times, from the 2026-10-21 migration). Also trims
    stray whitespace.
#}
{% macro clean_null(column_name) -%}
    nullif(nullif(trim({{ column_name }}), ''), '\\N')
{%- endmacro %}
