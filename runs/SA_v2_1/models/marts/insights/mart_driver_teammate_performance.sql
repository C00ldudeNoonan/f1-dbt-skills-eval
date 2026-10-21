-- Which drivers consistently beat the other driver in the same car? One row per driver with enough
-- teammate comparisons to say anything. See docs/leadership_answers.md for definitions and caveats.
--   qualifying gap : best qualifying time vs teammate (%), negative = faster; cluster-robust 95% interval
--   race-pace gap  : median green-flag lap vs teammate (%), same treatment (1996 onwards)
--   rating         : the same gaps solved jointly across all teammate pairs (int_driver_*_ratings), so
--                    beating a weak teammate counts for less than beating a strong one
--   head to head   : share of shared qualifying sessions / races ahead, with a Wilson 95% interval
-- verdict needs: >= 40 qualifying sessions, >= 2 different teammates, >= 4 season-teammate clusters.
with quali as (

    select * from ({{ teammate_gap_stats(ref('int_teammate_qualifying_gaps')) }})

),

pace as (

    select * from ({{ teammate_gap_stats(ref('int_teammate_pace_gaps')) }})

),

head_to_head as (

    select
        driver_id,
        sum(qualifying_ahead) as quali_ahead,
        sum(qualifying_together) as quali_together,
        sum(races_ahead) as races_ahead,
        sum(races_together) as races_together
    from {{ ref('mart_teammate_head_to_head') }}
    group by driver_id

),

seasons as (

    select driver_id, min(season) as first_season, max(season) as last_season
    from {{ ref('fct_results') }}
    group by driver_id

),

joined as (

    select
        quali.driver_id,
        drivers.first_name,
        drivers.last_name,
        seasons.first_season,
        seasons.last_season,
        quali.sessions as quali_sessions,
        quali.teammates as quali_teammates,
        quali.clusters as quali_clusters,
        quali.mean_gap_pct as quali_gap_pct,
        quali.se_pct as quali_se_pct,
        quali.ci_low_pct as quali_ci_low_pct,
        quali.ci_high_pct as quali_ci_high_pct,
        quali_rating.rating_pct as quali_rating_pct,
        pace.sessions as pace_sessions,
        pace.clusters as pace_clusters,
        pace.mean_gap_pct as pace_gap_pct,
        pace.ci_low_pct as pace_ci_low_pct,
        pace.ci_high_pct as pace_ci_high_pct,
        pace_rating.rating_pct as pace_rating_pct,
        head_to_head.quali_together,
        head_to_head.quali_ahead / nullif(head_to_head.quali_together, 0) as quali_head_to_head_share,
        head_to_head.races_together,
        head_to_head.races_ahead / nullif(head_to_head.races_together, 0) as race_head_to_head_share
    from quali
    inner join {{ ref('dim_drivers') }} as drivers on quali.driver_id = drivers.driver_id
    inner join seasons on quali.driver_id = seasons.driver_id
    left join {{ ref('int_driver_quali_ratings') }} as quali_rating on quali.driver_id = quali_rating.driver_id
    left join pace on quali.driver_id = pace.driver_id
    left join {{ ref('int_driver_pace_ratings') }} as pace_rating on quali.driver_id = pace_rating.driver_id
    left join head_to_head on quali.driver_id = head_to_head.driver_id

),

with_interval as (

    select
        *,
        -- Wilson 95% interval for the qualifying head-to-head share
        (quali_head_to_head_share + 1.92 / quali_together
            - 1.96 * sqrt(quali_head_to_head_share * (1 - quali_head_to_head_share) / quali_together + 0.9604 / power(quali_together, 2)))
            / (1 + 3.8416 / quali_together) as quali_h2h_ci_low,
        (quali_head_to_head_share + 1.92 / quali_together
            + 1.96 * sqrt(quali_head_to_head_share * (1 - quali_head_to_head_share) / quali_together + 0.9604 / power(quali_together, 2)))
            / (1 + 3.8416 / quali_together) as quali_h2h_ci_high,
        quali_sessions >= 40 and quali_teammates >= 2 and quali_clusters >= 4 as has_enough_evidence
    from joined

)

select
    *,
    case
        when not has_enough_evidence then 'insufficient_data'
        when quali_ci_high_pct < 0 and quali_rating_pct <= -0.10
            and coalesce(pace_ci_low_pct <= 0 and pace_rating_pct <= 0, true) then 'consistently_faster_than_teammates'
        when quali_ci_low_pct > 0 and quali_rating_pct >= 0.10
            and coalesce(pace_ci_high_pct >= 0 and pace_rating_pct >= 0, true) then 'consistently_slower_than_teammates'
        else 'inconclusive'
    end as verdict
from with_interval
