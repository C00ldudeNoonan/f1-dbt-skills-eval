{#-
    QUALIFY clause that keeps one row per natural key. Staging uses it on every
    raw table so a duplicated raw row can never fan out a join downstream
    (October 2026: a second copy of Ferrari's CONSTRUCTORS row doubled every
    Ferrari result in fct_results).

    Exact copies are harmless and collapse silently; the raw_<table>__no_duplicate_rows
    source test still reports them. Copies whose values disagree fail
    raw_<table>__no_conflicting_duplicates, which stops the build before staging
    runs, because no rule can know which version is right. If staging is ever
    run without tests, the row with the lowest order_by value wins.
-#}
{% macro dedupe_on(key_columns, order_by) -%}
qualify row_number() over (
    partition by {{ key_columns | join(', ') }}
    order by {{ order_by }}
) = 1
{%- endmacro %}
