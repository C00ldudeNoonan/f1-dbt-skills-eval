{#-
    "Which drivers overperform their car?" One row per driver with same-car
    comparisons (1994+).

    The only clean control for car performance is the teammate: same car, same
    weekend. Two independent signals:
      * qualifying: gap to teammate in the last session both set a time in
      * race pace: gap in median green-flag lap time (1996+)
    For each: the raw same-car gap, and a rating adjusted for teammate strength
    across the whole teammate network with a 95% interval
    (int_driver_network_ratings). Ratings are % of lap time versus the average
    driver in the same car; negative = faster.

    is_trusted_overperformer: in the main connected group, enough comparisons,
    and the 95% interval entirely faster than average on BOTH signals.
-#}
with quali_gaps as (

    select * from {{ ref('int_teammate_qualifying_gaps') }}
    where is_representative

),

race_gaps as (

    select * from {{ ref('int_teammate_race_pace_gaps') }}
    where is_representative

),

ratings as (

    select * from {{ ref('int_driver_network_ratings') }}

),

quali_summary as (

    select
        driver_id,
        count(*) as quali_comparisons,
        count(distinct teammate_id) as quali_teammates,
        avg(gap_pct) as quali_raw_gap_pct,
        count_if(gap_pct < 0) / count(*) as quali_share_ahead,
        min(season) as first_season,
        max(season) as last_season
    from quali_gaps
    group by 1

),

race_summary as (

    select
        driver_id,
        count(*) as race_comparisons,
        count(distinct teammate_id) as race_teammates,
        avg(gap_pct) as race_raw_gap_pct,
        count_if(gap_pct < 0) / count(*) as race_share_ahead
    from race_gaps
    group by 1

),

quali_rating as (

    select * from ratings where signal = 'qualifying'

),

race_rating as (

    select * from ratings where signal = 'race_pace'

),

combined as (

    select
        quali_summary.*,
        quali_rating.rating_pct as quali_rating_pct,
        quali_rating.rating_se_pct as quali_rating_se_pct,
        coalesce(quali_rating.is_main_component, false) as quali_in_main_network,
        race_summary.race_comparisons,
        race_summary.race_teammates,
        race_summary.race_raw_gap_pct,
        race_summary.race_share_ahead,
        race_rating.rating_pct as race_rating_pct,
        race_rating.rating_se_pct as race_rating_se_pct,
        coalesce(race_rating.is_main_component, false) as race_in_main_network
    from quali_summary
    left join quali_rating
        on quali_summary.driver_id = quali_rating.driver_id
    left join race_summary
        on quali_summary.driver_id = race_summary.driver_id
    left join race_rating
        on quali_summary.driver_id = race_rating.driver_id

),

flagged as (

    select
        *,
        coalesce(
            quali_in_main_network
            and race_in_main_network
            and quali_comparisons >= {{ var('trusted_min_qualifying_comparisons') }}
            and race_comparisons >= {{ var('trusted_min_race_comparisons') }}
            and quali_rating_pct + 1.96 * quali_rating_se_pct < 0
            and race_rating_pct + 1.96 * race_rating_se_pct < 0,
            false
        ) as is_trusted_overperformer
    from combined

)

select
    flagged.driver_id,
    drivers.driver_ref,
    drivers.first_name || ' ' || drivers.last_name as driver_name,
    flagged.first_season,
    flagged.last_season,
    flagged.quali_comparisons,
    flagged.quali_teammates,
    round(flagged.quali_raw_gap_pct, 3) as quali_raw_gap_pct,
    round(flagged.quali_share_ahead, 3) as quali_share_ahead,
    round(flagged.quali_rating_pct, 3) as quali_rating_pct,
    round(flagged.quali_rating_pct - 1.96 * flagged.quali_rating_se_pct, 3) as quali_rating_ci_low,
    round(flagged.quali_rating_pct + 1.96 * flagged.quali_rating_se_pct, 3) as quali_rating_ci_high,
    flagged.race_comparisons,
    flagged.race_teammates,
    round(flagged.race_raw_gap_pct, 3) as race_raw_gap_pct,
    round(flagged.race_share_ahead, 3) as race_share_ahead,
    round(flagged.race_rating_pct, 3) as race_rating_pct,
    round(flagged.race_rating_pct - 1.96 * flagged.race_rating_se_pct, 3) as race_rating_ci_low,
    round(flagged.race_rating_pct + 1.96 * flagged.race_rating_se_pct, 3) as race_rating_ci_high,
    flagged.quali_in_main_network and flagged.race_in_main_network as in_main_network,
    flagged.is_trusted_overperformer,
    case when flagged.is_trusted_overperformer then
        rank() over (
            partition by flagged.is_trusted_overperformer
            order by flagged.quali_rating_pct + flagged.race_rating_pct
        )
    end as trusted_rank
from flagged
inner join {{ ref('dim_drivers') }} as drivers
    on flagged.driver_id = drivers.driver_id
