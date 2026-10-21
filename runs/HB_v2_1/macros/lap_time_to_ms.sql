{#
    Converts an Ergast lap time string such as '1:27.452' (m:ss.SSS) to
    milliseconds. Anything that does not match the format returns NULL.
    Hours are not supported because no lap time or fastest lap in the
    source exceeds one hour.
#}
{% macro lap_time_to_ms(column_name) -%}
    case
        when regexp_like({{ column_name }}, '^[0-9]+:[0-5][0-9][.][0-9]{3}$')
            then (try_cast(split_part({{ column_name }}, ':', 1) as integer) * 60
                + try_cast(split_part(split_part({{ column_name }}, ':', 2), '.', 1) as integer)) * 1000
                + try_cast(split_part({{ column_name }}, '.', 2) as integer)
    end
{%- endmacro %}
