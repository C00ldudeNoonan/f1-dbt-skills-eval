{#- Parse an Ergast lap/qualifying time such as '1:23.456' into integer milliseconds.
    Anything that is not m:ss.mmm (including the \N sentinel and blanks) becomes null. -#}
{% macro lap_time_to_ms(column) -%}
    case
        when regexp_like(trim({{ column }}), '[0-9]+:[0-9]{2}[.][0-9]{3}')
        then (split_part(trim({{ column }}), ':', 1)::integer * 60000
              + split_part(split_part(trim({{ column }}), ':', 2), '.', 1)::integer * 1000
              + split_part(trim({{ column }}), '.', 2)::integer)
    end
{%- endmacro %}
