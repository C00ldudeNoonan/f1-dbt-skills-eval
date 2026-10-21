{{ config(severity='warn') }}
{#
    Exact duplicate rows in the raw feed (same content, different id). dedupe_raw removes them
    before staging, so the numbers are correct. This warning keeps the feed fault visible in
    every build until the vendor fixes it.
#}
{% set keys = raw_keys() %}
{% set contract = raw_contract() %}
{% set raw = source('f1_raw', 'RACES') %}
{% for table_name, columns in contract.items() if keys[table_name].get('scan', true) %}
    {% set spec = keys[table_name] %}
    {% set content = columns | reject('equalto', spec.id) | list if spec.id else columns %}
select
    '{{ table_name }}' as table_name,
    (select count(*) from {{ source('f1_raw', table_name) }})
        - (select count(*) from ({{ dedupe_raw(source('f1_raw', table_name), spec.id) }})) as exact_duplicate_rows
{{ 'union all' if not loop.last }}
{% endfor %}
where exact_duplicate_rows > 0
