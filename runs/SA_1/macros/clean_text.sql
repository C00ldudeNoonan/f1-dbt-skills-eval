{# Raw files were loaded as text; missing values appear as the literal \N. #}
{% macro clean_text(column) -%}
    nullif(trim({{ column }}), '\\N')
{%- endmacro %}

{# Parse an m:ss.mmm lap time string into integer milliseconds (null-safe). #}
{% macro lap_time_to_ms(column) -%}
    case
        when {{ clean_text(column) }} is null then null
        else split_part({{ column }}, ':', 1)::int * 60000
            + round(split_part({{ column }}, ':', 2)::float * 1000)::int
    end
{%- endmacro %}
