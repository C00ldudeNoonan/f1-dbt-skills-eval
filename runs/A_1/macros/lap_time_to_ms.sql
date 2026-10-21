{#
  Convert an Ergast lap time string to integer milliseconds.
  Handles 'M:SS.mmm' (e.g. 1:27.452) and bare 'SS.mmm' (e.g. 59.123).
  Returns null for anything unparseable.
#}

{% macro lap_time_to_ms(column) -%}
    case
        when {{ clean_text(column) }} regexp '^[0-9]+:[0-9]{1,2}\\.[0-9]+$'
            then round(
                try_to_number(split_part({{ clean_text(column) }}, ':', 1)) * 60000
                + try_to_decimal(split_part({{ clean_text(column) }}, ':', 2), 9, 3) * 1000
            )::integer
        when {{ clean_text(column) }} regexp '^[0-9]+\\.[0-9]+$'
            then round(try_to_decimal({{ clean_text(column) }}, 9, 3) * 1000)::integer
    end
{%- endmacro %}
