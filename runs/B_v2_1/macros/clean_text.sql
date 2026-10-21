{#-
  The raw Ergast CSVs were loaded as text, with `\N` as the null marker and
  occasional empty strings (e.g. qualifying Q2/Q3). Normalise both to null.
-#}
{% macro clean_text(column) -%}
    nullif(nullif(trim({{ column }}), '\\N'), '')
{%- endmacro %}

{#- Cast cleaned text to an integer. Non-numeric text (e.g. 'R', 'D') becomes null. -#}
{% macro clean_int(column) -%}
    try_to_number({{ clean_text(column) }})::integer
{%- endmacro %}

{#- Cast cleaned text to a decimal (points can be fractional, e.g. 0.5, 1.33). -#}
{% macro clean_decimal(column, precision=10, scale=2) -%}
    try_to_number({{ clean_text(column) }}, {{ precision }}, {{ scale }})
{%- endmacro %}

{#-
  Parse a date using explicit formats only. Never rely on Snowflake's AUTO
  detection: it can return null or swap day and month for some values (e.g.
  '05/03/2009') without raising an error. The vendor sent ISO dates until its
  2026-10-21 pipeline migration, then switched RACES.DATE to DD/MM/YYYY; both
  formats are unambiguous, so accept either.
-#}
{% macro parse_date(column) -%}
    coalesce(
        try_to_date({{ clean_text(column) }}, 'YYYY-MM-DD'),
        try_to_date({{ clean_text(column) }}, 'DD/MM/YYYY')
    )
{%- endmacro %}

{#-
  Name key for cross-feed matching: upper case, accents removed, anything but
  letters dropped ('Pérez' -> 'PEREZ', 'de Vries' -> 'DEVRIES', 'Hülkenberg' -> 'HULKENBERG').
-#}
{% macro name_key(column) -%}
    regexp_replace(
        translate(upper({{ column }}), 'ÁÀÂÄÃÅĄÉÈÊËĘÍÌÎÏÓÒÔÖÕØÚÙÛÜÝŸÑŃÇĆČŠŚŽŹŻŁĐ', 'AAAAAAAEEEEEIIIIOOOOOOUUUUYYNNCCCSSZZZLD'),
        '[^A-Z]', ''
    )
{%- endmacro %}
