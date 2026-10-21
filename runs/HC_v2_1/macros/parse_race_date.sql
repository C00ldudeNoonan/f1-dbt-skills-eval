{#
    Race dates arrive as ISO (2009-03-29) for the first load and as DD/MM/YYYY (29/03/2009) since the
    2026-10-21 vendor migration. Both are parsed here. Anything else returns NULL, and the not_null test on
    race_date then fails the build, so an unknown format cannot pass silently.
#}
{% macro parse_race_date(column_name) -%}
    coalesce(
        try_to_date({{ column_name }}, 'YYYY-MM-DD'),
        try_to_date({{ column_name }}, 'DD/MM/YYYY')
    )
{%- endmacro %}
