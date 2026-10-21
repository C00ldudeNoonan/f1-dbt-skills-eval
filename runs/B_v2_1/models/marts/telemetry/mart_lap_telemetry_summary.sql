{#-
  One row per driver per lap with telemetry. Incremental, replaced a race at
  a time (delete+insert on race_id).

  Each routine run finds the races fct_telemetry rewrote since this model last
  ran (fct_telemetry.ingested_at later than the newest source_ingested_at
  here) and recomputes every lap of those races from all their samples. It
  recomputes rather than patching with deltas, so max, average and
  percentages stay exact however late a sample arrives. Reads of
  fct_telemetry are limited to those races (literal list, partitions pruned).
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

{%- set races_to_build = none -%}
{%- if is_incremental() -%}
    {%- set watermark = telemetry_watermark(this, 'source_ingested_at') -%}
    {%- if watermark -%}
        {%- set races_to_build = telemetry_race_list(ref('fct_telemetry'), 'race_id', 'ingested_at > ' ~ watermark) -%}
    {%- endif -%}
{%- endif %}

select
    race_id,
    driver_id,
    lap,
    count(*)                                                        as samples,
    max(speed_kph)                                                  as max_speed_kph,
    avg(throttle_pct)::number(6, 2)                                 as avg_throttle_pct,
    (100 * count_if(throttle_pct >= 99) / count(*))::number(6, 2)   as full_throttle_pct,
    count_if(brake)                                                 as brake_samples,
    max(ingested_at)                                                as source_ingested_at
from {{ ref('fct_telemetry') }}
{% if races_to_build %}
-- Races rewritten in fct_telemetry since the last run: {{ races_to_build }}
where race_id in {{ races_to_build }}
{% endif %}
group by race_id, driver_id, lap
