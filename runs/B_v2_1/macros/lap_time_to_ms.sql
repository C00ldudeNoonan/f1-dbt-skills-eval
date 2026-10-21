{#-
  Convert an Ergast lap/qualifying time string ('m:ss.mmm', e.g. '1:26.993')
  to integer milliseconds. Anything not in that shape returns null.
-#}
{% macro lap_time_to_ms(column) -%}
    case
        when regexp_like({{ clean_text(column) }}, '^[0-9]+:[0-9]{2}\\.[0-9]{3}$')
        then split_part({{ clean_text(column) }}, ':', 1)::integer * 60000
            + round(split_part({{ clean_text(column) }}, ':', 2)::number(6, 3) * 1000)::integer
    end
{%- endmacro %}
