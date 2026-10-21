{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        cluster_by=['race_id']
    )
}}

{#
    One row per driver per lap, summarising the telemetry samples. Incremental by race, like fct_telemetry: the races
    that gained samples since the last run are rebuilt in full, so a late sample updates its lap correctly.

    full_throttle_pct is the share of samples with throttle at 99% or above, as a percentage.
    source_loaded_at is the latest load time among the lap's samples, which is the summary's own watermark.
#}
with changed as (

    select distinct race_id
    from {{ ref('fct_telemetry') }}
    {%- if is_incremental() %}
    where loaded_at > (
        select dateadd(hour, -48, max(source_loaded_at))
        from {{ this }}
    )
    {%- endif %}

)

select
    samples.race_id,
    samples.driver_id,
    samples.lap,
    count(*) as samples,
    max(samples.speed_kph) as max_speed_kph,
    avg(samples.throttle_pct) as avg_throttle_pct,
    count_if(samples.throttle_pct >= 99) * 100.0 / count(*) as full_throttle_pct,
    count_if(samples.brake) as brake_samples,
    max(samples.loaded_at) as source_loaded_at
from {{ ref('fct_telemetry') }} as samples
where samples.race_id in (select race_id from changed)
group by samples.race_id, samples.driver_id, samples.lap
