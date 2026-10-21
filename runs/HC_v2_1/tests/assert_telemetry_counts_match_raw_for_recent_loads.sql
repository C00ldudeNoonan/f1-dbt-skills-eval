{#
    For races that received samples in the last three days, the samples in fct_telemetry must equal the raw samples.
    Limited to recent loads so routine runs do not scan the whole raw table.
#}
with recent_races as (

    select distinct race_id
    from {{ ref('stg_f1__car_telemetry') }}
    where loaded_at >= dateadd(day, -3, current_timestamp())

),

raw_counts as (

    select race_id, count(*) as raw_samples
    from {{ ref('stg_f1__car_telemetry') }}
    where race_id in (select race_id from recent_races)
    group by race_id

),

model_counts as (

    select race_id, count(*) as model_samples
    from {{ ref('fct_telemetry') }}
    where race_id in (select race_id from recent_races)
    group by race_id

)

select
    raw_counts.race_id,
    raw_counts.raw_samples,
    coalesce(model_counts.model_samples, 0) as model_samples
from raw_counts
left join model_counts
    on raw_counts.race_id = model_counts.race_id
where raw_counts.raw_samples <> coalesce(model_counts.model_samples, 0)
