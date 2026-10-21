{#-
    The raw Ergast extract was loaded as text exactly as it appeared in the CSVs.
    Missing values appear as the literal string \N, and a few qualifying times are
    empty strings. This macro turns both into SQL nulls and trims whitespace.
-#}
{% macro clean_text(column) -%}
    nullif(nullif(trim({{ column }}), '\\N'), '')
{%- endmacro %}


{#-
    Cast a cleaned text column to an integer. Anything that is not an optionally
    signed run of digits becomes null (and is reported by the values_parse
    source test). A regex guard is used because try_to_number('E') returns 0
    and try_to_number('1.5') silently rounds.
-#}
{% macro to_int(column) -%}
    iff(regexp_like({{ clean_text(column) }}, '-?[0-9]+'), {{ clean_text(column) }}::integer, null)
{%- endmacro %}


{#-
    Parse a cleaned text date. Accepts exactly the formats in var('raw_date_formats'),
    tried in order. The vendor switched RACES.DATE from YYYY-MM-DD to DD/MM/YYYY
    in October 2026. A value matching none of them becomes null and fails the
    values_parse source test, so a new format can't slip through silently.
-#}
{% macro to_date(column) -%}
    {%- set formats = var('raw_date_formats') -%}
    {%- if formats | length == 1 -%}
        try_to_date({{ clean_text(column) }}, '{{ formats[0] }}')
    {%- else -%}
        coalesce(
        {%- for fmt in formats %}
            try_to_date({{ clean_text(column) }}, '{{ fmt }}'){{ ',' if not loop.last }}
        {%- endfor %}
        )
    {%- endif -%}
{%- endmacro %}


{#- Parse a cleaned text time of day (HH:MI:SS). -#}
{% macro to_time(column) -%}
    try_to_time({{ clean_text(column) }})
{%- endmacro %}


{#- Parse a cleaned text column with the parser for the given type name. -#}
{% macro parse_as(column, type) -%}
    {%- if type == 'int' -%} {{ to_int(column) }}
    {%- elif type == 'decimal' -%} {{ to_decimal(column) }}
    {%- elif type == 'date' -%} {{ to_date(column) }}
    {%- elif type == 'time' -%} {{ to_time(column) }}
    {%- elif type == 'duration' -%} {{ duration_to_ms(column) }}
    {%- else -%} {{ exceptions.raise_compiler_error("parse_as: unknown type '" ~ type ~ "'") }}
    {%- endif -%}
{%- endmacro %}


{#- Cast a cleaned text column to a decimal number. -#}
{% macro to_decimal(column, precision=12, scale=3) -%}
    try_to_decimal({{ clean_text(column) }}, {{ precision }}, {{ scale }})
{%- endmacro %}
