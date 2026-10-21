{#- One row per driver per lap. Incremental by race: a race is recomputed in full (from
    fct_telemetry, so only that race's partitions are read) whenever it received samples
    since this table's own watermark, including late ones. delete+insert by race_id also
    removes anything a correction invalidated. -#}
{% set watermark = telemetry_watermark(this, 'last_loaded_at') if is_incremental() else none %}
{% set affected_races = telemetry_affected_races(ref('fct_telemetry'), watermark) if is_incremental() else '-1' %}

{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

select
    race_id,
    driver_id,
    lap,
    count(*)::integer as samples,
    max(speed_kph)::number(6, 1) as max_speed_kph,
    avg(throttle_pct)::double as avg_throttle_pct,
    (100.0 * count_if(throttle_pct >= 99) / count(*))::double as full_throttle_pct,
    count_if(brake)::integer as brake_samples,
    max(loaded_at) as last_loaded_at
from {{ ref('fct_telemetry') }}
{% if is_incremental() %}
where race_id in ({{ affected_races }})
{% endif %}
group by race_id, driver_id, lap
