{#- Converts an 'm:ss.mmm' lap-time string (already NULL-cleaned) into integer milliseconds. -#}
{% macro lap_time_to_ms(column) -%}
    case
        when {{ column }} is null then null
        else
            split_part({{ column }}, ':', 1)::int * 60000
            + round(split_part({{ column }}, ':', 2)::number(8, 3) * 1000)::int
    end
{%- endmacro %}
