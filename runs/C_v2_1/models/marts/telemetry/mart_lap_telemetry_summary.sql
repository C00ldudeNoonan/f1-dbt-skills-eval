{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

-- One row per driver per lap. Incremental by whole race: rebuilds the races
-- whose fct_telemetry samples were loaded after this table's high-water mark
-- (telemetry_loaded_at), so a late sample re-aggregates its race and every lap
-- stays exact. It only reads fct_telemetry for those races.

{% set races = telemetry_races_to_process(
    this, 'telemetry_loaded_at',
    ref('fct_telemetry'), 'source_loaded_at', 'race_id'
) if is_incremental() else none %}

with samples as (
    select *
    from {{ ref('fct_telemetry') }}
    {% if races is not none %}
    where {{ race_filter('race_id', races) }}
    {% endif %}
)

select
    race_id,
    driver_id,
    lap,
    count(*) as samples,
    max(speed_kph) as max_speed_kph,
    avg(throttle_pct)::number(6, 2) as avg_throttle_pct,
    (100 * count_if(throttle_pct >= 99) / count(*))::number(6, 2) as full_throttle_pct,
    count_if(brake) as brake_samples,
    max(source_loaded_at) as telemetry_loaded_at,
    sysdate() as processed_at
from samples
group by race_id, driver_id, lap
order by race_id, driver_id, lap
