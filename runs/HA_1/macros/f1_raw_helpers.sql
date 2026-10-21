{#
    The Ergast/Kaggle CSVs were loaded as text. Missing values arrive as the
    literal two-character string \N, so every nullable column goes through
    null_marker() before casting.
#}

{% macro null_marker(column_name) -%}
    nullif(trim({{ column_name }}), '\\N')
{%- endmacro %}


{#
    Converts a race lap time such as '1:32.456' (or '32.456' with no minutes)
    to integer milliseconds. Returns null for the \N marker.
#}

{% macro lap_time_to_ms(column_name) -%}
    {%- set value = null_marker(column_name) -%}
    (
        case
            when {{ value }} is null then null
            when contains({{ value }}, ':') then
                split_part({{ value }}, ':', 1)::number(10, 0) * 60000
                + round(split_part({{ value }}, ':', 2)::number(10, 3) * 1000)
            else round({{ value }}::number(10, 3) * 1000)
        end
    )::integer
{%- endmacro %}
