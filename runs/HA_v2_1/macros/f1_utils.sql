{#
    The raw Ergast/Kaggle load stores missing values as the literal text \N
    (and occasionally as an empty string). Map both to real NULLs.
#}
{% macro clean_null(column) -%}
    nullif(nullif(trim({{ column }}), '\\N'), '')
{%- endmacro %}

{#
    Parse an Ergast lap or qualifying time ("m:ss.mmm") into integer milliseconds.
    Anything that does not match the pattern returns NULL rather than guessing.
#}
{% macro lap_time_to_ms(column) -%}
    case
        when {{ column }} rlike '^[0-9]+:[0-9]{2}\\.[0-9]{3}$'
            then split_part({{ column }}, ':', 1)::int * 60000
                + split_part(split_part({{ column }}, ':', 2), '.', 1)::int * 1000
                + split_part({{ column }}, '.', 2)::int
    end
{%- endmacro %}
