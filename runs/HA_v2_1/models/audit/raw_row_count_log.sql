{{
    config(
        materialized='incremental',
        incremental_strategy='append'
    )
}}
{#
    One row per raw table per successful build: the raw row count at that time.
    assert_raw_contract compares the next run against the latest row here, to block
    truncated loads. Append-only, so history is kept.
#}
{% set contract = raw_contract() %}
{% for table_name in contract.keys() %}
{% set relation = source('f1_telemetry', 'CAR_TELEMETRY') if table_name == 'CAR_TELEMETRY' else source('f1_raw', table_name) %}
select
    current_timestamp() as loaded_at,
    '{{ table_name }}' as table_name,
    (select count(*) from {{ relation }}) as row_count
{{ 'union all' if not loop.last }}
{% endfor %}
