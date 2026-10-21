-- One row per signal per driver/teammate pair (both orderings), summarising
-- their representative same-car gaps: count, mean, and within-pair sum of
-- squared deviations (for the rating's standard errors).
with gaps as (

    select 'qualifying' as signal, driver_id, teammate_id, gap_pct
    from {{ ref('int_teammate_qualifying_gaps') }}
    where is_representative

    union all

    select 'race_pace', driver_id, teammate_id, gap_pct
    from {{ ref('int_teammate_race_pace_gaps') }}
    where is_representative

)

select
    signal,
    driver_id,
    teammate_id,
    count(*) as comparisons,
    avg(gap_pct) as mean_gap_pct,
    coalesce(var_samp(gap_pct) * (count(*) - 1), 0) as sum_sq_dev
from gaps
group by 1, 2, 3
