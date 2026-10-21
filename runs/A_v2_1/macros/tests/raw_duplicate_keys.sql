{#-
    Duplicate-row checks on a raw source table, by its natural key.

    check='conflicting'  fails for each key that appears with more than one
                         version of the row, comparing cleaned values (trimmed,
                         \N as null) and ignoring surrogate id columns.
                         Severity error: staging can't know which is right.
    check='exact'        fails for each key that appears more than once with
                         identical content. Staging collapses these, so use
                         severity warn: it tells you the feed is sending copies.

    key_columns:    raw columns forming the natural key.
    ignore_columns: surrogate ids to leave out when comparing content (a copy
                    re-issued under a new id is still a copy).
-#}
{% test raw_duplicate_keys(model, key_columns, ignore_columns=[], check='conflicting') %}

with hashed as (

    -- Compare cleaned values (what staging sees), not raw bytes.
    select
        {{ key_columns | join(', ') }},
        {{ raw_row_hash(model, ignore_columns) }} as row_content
    from {{ model }}

)

select
    {{ key_columns | join(', ') }},
    count(*) as copies,
    count(distinct row_content) as versions
from hashed
group by {{ key_columns | join(', ') }}
{% if check == 'conflicting' %}
having count(distinct row_content) > 1
{% elif check == 'exact' %}
having count(*) > 1 and count(distinct row_content) = 1
{% else %}
{{ exceptions.raise_compiler_error("raw_duplicate_keys: check must be 'conflicting' or 'exact'") }}
{% endif %}

{% endtest %}
