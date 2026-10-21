{#
    The summary's sample counts must equal the samples it summarises, for races loaded in the last three days.
#}
with recent_races as (

    select distinct race_id
    from {{ ref('fct_telemetry') }}
    where loaded_at >= dateadd(day, -3, current_timestamp())

),

sample_totals as (

    select race_id, count(*) as samples
    from {{ ref('fct_telemetry') }}
    where race_id in (select race_id from recent_races)
    group by race_id

),

summary_totals as (

    select race_id, sum(samples) as summarised
    from {{ ref('mart_lap_telemetry_summary') }}
    where race_id in (select race_id from recent_races)
    group by race_id

)

select
    sample_totals.race_id,
    sample_totals.samples,
    coalesce(summary_totals.summarised, 0) as summarised
from sample_totals
left join summary_totals
    on sample_totals.race_id = summary_totals.race_id
where sample_totals.samples <> coalesce(summary_totals.summarised, 0)
