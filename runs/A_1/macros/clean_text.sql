{#
  The raw Ergast/Kaggle CSVs were loaded as text, verbatim. Missing values are
  the literal two-character string \N, and some values carry stray whitespace.
  Every staging column goes through one of these helpers so the null marker is
  handled in exactly one place.
#}

{% macro clean_text(column) -%}
    nullif(nullif(trim({{ column }}), '\\N'), '')
{%- endmacro %}

{% macro to_int(column) -%}
    try_to_number({{ clean_text(column) }})::integer
{%- endmacro %}

{% macro to_decimal(column, precision=10, scale=2) -%}
    try_to_decimal({{ clean_text(column) }}, {{ precision }}, {{ scale }})
{%- endmacro %}

{% macro to_date(column) -%}
    try_to_date({{ clean_text(column) }}, 'YYYY-MM-DD')
{%- endmacro %}
