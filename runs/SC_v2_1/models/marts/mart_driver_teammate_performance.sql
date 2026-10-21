{#- "Does this driver beat his car?" answered the only way this data supports it: against the
    teammate in the same car, in qualifying and in race pace (see the two int_ models for exact
    definitions). Unit of observation = one driver, one teammate, one season ("stint"): races within
    a stint are not independent (same two cars, same setup philosophy), so uncertainty is computed
    across stints, not across races. Negative scores mean FASTER than teammates.
    Because teammates are not random (beating a weak teammate proves little), each stint is also
    adjusted by how fast that teammate was against his OTHER teammates (leave-one-out), a first-order
    version of a network rating; the verdict uses the adjusted score. The adjustment is approximate
    and ignores the uncertainty in the teammates' own ratings, so intervals are a little optimistic.
    A driver is only given a verdict with at least min_stints stints against at least
    min_teammates different teammates; everything else is 'insufficient_data', not a guess. -#}
{% set min_pairs_per_component = 3 %}
{% set min_stints = 5 %}
{% set min_teammates = 3 %}

with quali as (

    select
        driver_id, teammate_id, season,
        count(*) as pairs,
        avg(delta_pct) as mean_delta_pct
    from {{ ref('int_f1__teammate_quali_deltas') }}
    group by all

),

pace as (

    select
        driver_id, teammate_id, season,
        count(*) as pairs,
        avg(delta_pct) as mean_delta_pct
    from {{ ref('int_f1__teammate_pace_deltas') }}
    group by all

),

stints as (

    select
        coalesce(quali.driver_id, pace.driver_id) as driver_id,
        coalesce(quali.teammate_id, pace.teammate_id) as teammate_id,
        coalesce(quali.season, pace.season) as season,
        coalesce(quali.pairs, 0) as quali_pairs,
        coalesce(pace.pairs, 0) as pace_pairs,
        iff(quali.pairs >= {{ min_pairs_per_component }}, quali.mean_delta_pct, null) as quali_delta_pct,
        iff(pace.pairs >= {{ min_pairs_per_component }}, pace.mean_delta_pct, null) as pace_delta_pct
    from quali
    full outer join pace
        on quali.driver_id = pace.driver_id
        and quali.teammate_id = pace.teammate_id
        and quali.season = pace.season

),

scored_stints as (

    select
        *,
        -- equal weight to each component that has enough data
        (coalesce(quali_delta_pct, 0) + coalesce(pace_delta_pct, 0))
            / nullif(iff(quali_delta_pct is not null, 1, 0) + iff(pace_delta_pct is not null, 1, 0), 0) as stint_delta_pct
    from stints

),

driver_totals as (

    select
        driver_id,
        sum(stint_delta_pct) as total_delta_pct,
        count(stint_delta_pct) as stint_count
    from scored_stints
    group by driver_id

),

adjusted_stints as (

    select
        s.*,
        -- teammate's mean score against everyone except this driver. stint_delta_pct of the mirrored
        -- stint is -s.stint_delta_pct, so removing it from the teammate's total is "+ s.stint_delta_pct".
        s.stint_delta_pct + coalesce(
            (t.total_delta_pct + s.stint_delta_pct) / nullif(t.stint_count - 1, 0),
            0
        ) as adjusted_stint_delta_pct
    from scored_stints as s
    left join driver_totals as t on t.driver_id = s.teammate_id

),

by_driver as (

    select
        driver_id,
        count(stint_delta_pct) as stints,
        count(distinct iff(stint_delta_pct is not null, teammate_id, null)) as teammates,
        count(distinct iff(stint_delta_pct is not null, season, null)) as seasons,
        sum(quali_pairs) as quali_pairs,
        sum(pace_pairs) as pace_pairs,
        avg(quali_delta_pct) as quali_delta_pct,
        avg(pace_delta_pct) as pace_delta_pct,
        avg(stint_delta_pct) as raw_teammate_delta_pct,
        avg(adjusted_stint_delta_pct) as teammate_delta_pct,
        stddev(adjusted_stint_delta_pct) / sqrt(nullif(count(stint_delta_pct), 0)) as standard_error,
        count_if(stint_delta_pct < 0) / nullif(count(stint_delta_pct), 0) as share_of_stints_faster
    from adjusted_stints
    group by driver_id

),

verdicts as (

    select
        *,
        teammate_delta_pct - 1.96 * standard_error as ci_low_pct,
        teammate_delta_pct + 1.96 * standard_error as ci_high_pct,
        stints >= {{ min_stints }} and teammates >= {{ min_teammates }} as has_enough_data
    from by_driver

)

select
    verdicts.driver_id,
    drivers.full_name as driver_name,
    verdicts.seasons::integer as seasons,
    verdicts.teammates::integer as teammates,
    verdicts.stints::integer as stints,
    verdicts.quali_pairs::integer as quali_pairs,
    verdicts.pace_pairs::integer as pace_pairs,
    verdicts.quali_delta_pct::double as quali_delta_pct,
    verdicts.pace_delta_pct::double as pace_delta_pct,
    verdicts.raw_teammate_delta_pct::double as raw_teammate_delta_pct,
    verdicts.teammate_delta_pct::double as teammate_delta_pct,
    verdicts.standard_error::double as standard_error_pct,
    verdicts.ci_low_pct::double as ci_low_pct,
    verdicts.ci_high_pct::double as ci_high_pct,
    verdicts.share_of_stints_faster::double as share_of_stints_faster,
    case
        when not verdicts.has_enough_data then 'insufficient_data'
        when verdicts.ci_high_pct < 0 then 'outperforms_teammates'
        when verdicts.ci_low_pct > 0 then 'underperforms_teammates'
        else 'indistinguishable'
    end as verdict,
    iff(
        verdicts.has_enough_data,
        rank() over (partition by verdicts.has_enough_data order by verdicts.teammate_delta_pct),
        null
    )::integer as rank_among_rated
from verdicts
inner join {{ ref('stg_f1__drivers') }} as drivers on drivers.driver_id = verdicts.driver_id
where verdicts.stints > 0
