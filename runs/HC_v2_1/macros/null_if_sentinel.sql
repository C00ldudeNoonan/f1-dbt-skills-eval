{#
    The raw Ergast/Kaggle F1 files encode missing values as the literal text \N, and some
    text columns (qualifying Q2 and Q3) also hold empty strings. Every column in the raw
    schema is text, so this turns both forms into a real NULL.
#}
{% macro null_if_sentinel(column_name) -%}
    nullif(nullif(trim({{ column_name }}), ''), '\\N')
{%- endmacro %}
