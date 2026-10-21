{#- Raw F1 files were loaded as text. Missing values appear as the literal string \N
    (and occasionally as an empty string). Returns NULL for both. -#}
{% macro clean_raw(column_name) -%}
    nullif(nullif(trim({{ column_name }}), '\\N'), '')
{%- endmacro %}


{#- Converts a 'm:ss.mmm' lap/qualifying time string into integer milliseconds.
    Returns NULL for missing values or anything that does not match the format. -#}
{% macro time_text_to_ms(column_name) -%}
    case
        when regexp_like({{ clean_raw(column_name) }}, '^[0-9]+:[0-9]{2}\\.[0-9]{3}$')
        then (
            split_part({{ column_name }}, ':', 1)::integer * 60
            + split_part(split_part({{ column_name }}, ':', 2), '.', 1)::integer
        ) * 1000 + split_part({{ column_name }}, '.', 2)::integer
    end
{%- endmacro %}


{#- Parses a raw date string. The vendor has shipped both ISO (YYYY-MM-DD) and
    DD/MM/YYYY. Both are parsed with explicit formats (never the session default, which
    would silently swap day and month); anything else becomes NULL and is caught by the
    source format tests and not_null tests. -#}
{% macro parse_raw_date(column_name) -%}
    coalesce(
        try_to_date({{ clean_raw(column_name) }}, 'YYYY-MM-DD'),
        try_to_date({{ clean_raw(column_name) }}, 'DD/MM/YYYY')
    )
{%- endmacro %}


{#- De-duplicates a staging relation on its natural key. The vendor has re-sent rows
    (sometimes with a new surrogate id or stray whitespace); keeping one row per key stops
    them fanning out joins and inflating counts. Pass an order_by that makes the choice
    deterministic. Source tests warn when duplicates exist and fail when duplicates
    disagree with each other, so this never hides a real conflict. -#}
{% macro dedupe(key_columns, order_by=none) -%}
    qualify row_number() over (
        partition by {{ key_columns | join(', ') }}
        order by {{ (order_by or key_columns) | join(', ') }}
    ) = 1
{%- endmacro %}
