{#- Converts an Ergast lap time string ('m:ss.mmm') to integer milliseconds. Null in, null out. -#}
{% macro lap_time_to_ms(column_name) -%}
    case
        when {{ column_name }} is null then null
        else (
            split_part({{ column_name }}, ':', 1)::int * 60000
            + split_part(split_part({{ column_name }}, ':', 2), '.', 1)::int * 1000
            + split_part({{ column_name }}, '.', 2)::int
        )
    end
{%- endmacro %}
