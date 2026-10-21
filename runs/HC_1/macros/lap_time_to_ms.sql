{#- Converts an Ergast lap time such as '1:23.456' (m:ss.mmm) to integer milliseconds. -#}
{% macro lap_time_to_ms(column_name) %}
    case
        when {{ column_name }} is null then null
        else
            try_to_number(split_part({{ column_name }}, ':', 1)) * 60000
            + try_to_number(split_part(split_part({{ column_name }}, ':', 2), '.', 1)) * 1000
            + try_to_number(rpad(split_part(split_part({{ column_name }}, ':', 2), '.', 2), 3, '0'))
    end
{% endmacro %}
