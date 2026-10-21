{#- Converts an Ergast lap time such as '1:23.456' (or '59.123') into integer milliseconds. -#}
{% macro lap_time_to_ms(column_name) -%}
    cast(
        case
            when contains({{ column_name }}, ':') then
                cast(split_part({{ column_name }}, ':', 1) as int) * 60000
                + round(cast(split_part({{ column_name }}, ':', 2) as float) * 1000)
            else round(cast({{ column_name }} as float) * 1000)
        end
    as int)
{%- endmacro %}
