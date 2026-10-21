{#
    Converts an m:ss.mmm time string (for example 1:29.141) to integer milliseconds.
    Returns NULL for anything that does not match that shape, including the \N sentinel.
    Use this for text lap times only. Race-time and lap-time columns that already carry
    a MILLISECONDS value should use that column directly.
#}
{% macro lap_time_to_ms(column_name) -%}
    case
        when regexp_like({{ column_name }}, '^[0-9]+:[0-5][0-9]\\.[0-9]{3}$')
            then split_part({{ column_name }}, ':', 1)::integer * 60000
                + split_part(split_part({{ column_name }}, ':', 2), '.', 1)::integer * 1000
                + split_part({{ column_name }}, '.', 2)::integer
    end
{%- endmacro %}
