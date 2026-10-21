{#
    Helpers for the raw Ergast CSV loads, where every column is text and
    missing values are the literal string '\N'.
#}

{# Trim and convert Ergast null markers ('\N' or empty string) to SQL null. #}
{% macro ergast_clean(column_name) -%}
    nullif(nullif(trim({{ column_name }}), '\\N'), '')
{%- endmacro %}

{# Clean then cast to an integer. Non-numeric text fails loudly rather than silently nulling. #}
{% macro ergast_int(column_name) -%}
    cast({{ ergast_clean(column_name) }} as integer)
{%- endmacro %}

{% macro ergast_number(column_name, precision=10, scale=2) -%}
    cast({{ ergast_clean(column_name) }} as number({{ precision }}, {{ scale }}))
{%- endmacro %}

{% macro ergast_date(column_name) -%}
    to_date({{ ergast_clean(column_name) }}, 'YYYY-MM-DD')
{%- endmacro %}

{#
    Convert a lap-time string ('1:23.456' or '59.123') to integer milliseconds.
#}
{% macro lap_time_to_ms(column_name) -%}
    case
        when {{ ergast_clean(column_name) }} is null then null
        when contains({{ ergast_clean(column_name) }}, ':') then
            cast(
                cast(split_part({{ ergast_clean(column_name) }}, ':', 1) as integer) * 60000
                + round(cast(split_part({{ ergast_clean(column_name) }}, ':', 2) as number(6, 3)) * 1000)
            as integer)
        else cast(round(cast({{ ergast_clean(column_name) }} as number(6, 3)) * 1000) as integer)
    end
{%- endmacro %}
