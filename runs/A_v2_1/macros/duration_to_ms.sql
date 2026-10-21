{#-
    Convert an Ergast timing string to integer milliseconds.

    Handles the formats that appear in the raw data:
      - m:ss.mmm      lap and qualifying times, for example 1:26.572
      - mm:ss.mmm     long pit stops and outliers, for example 16:42.640
      - ss.mmm        pit stop durations, for example 23.456
    Anything else (including \N and empty strings) becomes null.

    Regexes use explicit character classes rather than backslash escapes so the
    pattern survives both Jinja and Snowflake string escaping unchanged.
-#}
{% macro duration_to_ms(column) -%}
    {%- set value = clean_text(column) -%}
    case
        when regexp_like({{ value }}, '[0-9]+:[0-9]{1,2}([.][0-9]+)?')
            then split_part({{ value }}, ':', 1)::integer * 60000
                + round(split_part({{ value }}, ':', 2)::number(12, 3) * 1000)::integer
        when regexp_like({{ value }}, '[0-9]+([.][0-9]+)?')
            then round({{ value }}::number(12, 3) * 1000)::integer
    end
{%- endmacro %}
