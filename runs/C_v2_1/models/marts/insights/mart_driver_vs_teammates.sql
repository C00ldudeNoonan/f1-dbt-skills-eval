-- Answers "which drivers overperform their car?" as well as the data allows.
-- One row per driver with teammate pace comparisons since 2006.
--
-- The car isn't observable, so the measure is the teammate, who drives the
-- same car. Beating a weak teammate is worth less than beating a strong one,
-- so each comparison is adjusted by the teammate's own record against their
-- other teammates:
--   adjusted = pace advantage over this teammate
--            + this teammate's median advantage over everyone else they partnered
-- That estimates the driver's pace against a typical teammate. Comparisons
-- where the teammate had no other teammates can't be adjusted and are left
-- out of the adjusted figure.
--
-- Trust tiers rest on sample size and breadth:
--   high    >= 60 clean comparisons, >= 3 different teammates, >= 40 adjusted
--   medium  >= 30 clean comparisons, >= 2 different teammates
--   low     everything else (rookies, short careers, single-teammate careers)
-- `verdict` is 'faster than typical teammate' only when the adjusted median is
-- above +0.1% and the qualifying head-to-head is significantly better than
-- 50/50 (Wilson 95% lower bound > 0.5). The reverse gives 'slower than
-- typical teammate'. Anything else is 'not distinguishable'.

with comparisons as (
    select *
    from {{ ref('int_f1__teammate_qualifying_comparisons') }}
    where not is_outlier
),

pairings as (
    select distinct driver_id, teammate_id
    from comparisons
),

teammate_baseline as (
    -- For each (teammate, excluded driver) pair: the teammate's median
    -- advantage over every partner other than the excluded driver.
    select
        partner.driver_id as teammate_id,
        excluded.driver_id as excluded_driver_id,
        median(partner.pace_advantage_pct) as teammate_baseline_pct
    from comparisons as partner
    inner join pairings as excluded
        on partner.driver_id = excluded.teammate_id
        and partner.teammate_id <> excluded.driver_id
    group by partner.driver_id, excluded.driver_id
),

adjusted as (
    select
        comparisons.*,
        comparisons.pace_advantage_pct + teammate_baseline.teammate_baseline_pct as adjusted_advantage_pct
    from comparisons
    left join teammate_baseline
        on comparisons.teammate_id = teammate_baseline.teammate_id
        and comparisons.driver_id = teammate_baseline.excluded_driver_id
),

all_comparisons as (
    select
        driver_id,
        count(*) as qualifying_comparisons,
        count_if(pace_advantage_pct > 0) as qualifying_wins
    from {{ ref('int_f1__teammate_qualifying_comparisons') }}
    group by driver_id
),

races as (
    select
        driver_id,
        sum(race_comparisons) as race_comparisons,
        sum(race_wins) as race_wins
    from {{ ref('mart_driver_season_vs_teammate') }}
    group by driver_id
),

per_driver as (
    select
        driver_id,
        min(season) as first_season,
        max(season) as last_season,
        count(distinct season) as seasons,
        count(distinct teammate_id) as distinct_teammates,
        count(*) as clean_comparisons,
        count(adjusted_advantage_pct) as adjusted_comparisons,
        median(pace_advantage_pct) as median_pace_advantage_pct,
        median(adjusted_advantage_pct) as adjusted_pace_advantage_pct
    from adjusted
    group by driver_id
),

scored as (
    select
        per_driver.*,
        all_comparisons.qualifying_comparisons,
        all_comparisons.qualifying_wins,
        all_comparisons.qualifying_wins / all_comparisons.qualifying_comparisons as qualifying_win_rate,
        {{ wilson_bound('all_comparisons.qualifying_wins', 'all_comparisons.qualifying_comparisons', 'lower') }} as qualifying_win_rate_lower_95,
        {{ wilson_bound('all_comparisons.qualifying_wins', 'all_comparisons.qualifying_comparisons', 'upper') }} as qualifying_win_rate_upper_95,
        coalesce(races.race_comparisons, 0) as race_comparisons,
        coalesce(races.race_wins, 0) as race_wins,
        races.race_wins / nullif(races.race_comparisons, 0) as race_win_rate,
        case
            when per_driver.clean_comparisons >= 60
                and per_driver.distinct_teammates >= 3
                and per_driver.adjusted_comparisons >= 40 then 'high'
            when per_driver.clean_comparisons >= 30
                and per_driver.distinct_teammates >= 2 then 'medium'
            else 'low'
        end as trust_tier
    from per_driver
    inner join all_comparisons
        on per_driver.driver_id = all_comparisons.driver_id
    left join races
        on per_driver.driver_id = races.driver_id
)

select
    scored.driver_id,
    drivers.driver_ref,
    drivers.first_name || ' ' || drivers.last_name as driver_name,
    scored.first_season,
    scored.last_season,
    scored.seasons,
    scored.distinct_teammates,
    scored.qualifying_comparisons,
    scored.clean_comparisons,
    scored.adjusted_comparisons,
    scored.median_pace_advantage_pct::float as median_pace_advantage_pct,
    scored.adjusted_pace_advantage_pct::float as adjusted_pace_advantage_pct,
    scored.qualifying_wins,
    scored.qualifying_win_rate::float as qualifying_win_rate,
    scored.qualifying_win_rate_lower_95::float as qualifying_win_rate_lower_95,
    scored.qualifying_win_rate_upper_95::float as qualifying_win_rate_upper_95,
    scored.race_comparisons,
    scored.race_wins,
    scored.race_win_rate::float as race_win_rate,
    scored.trust_tier,
    case
        when scored.trust_tier = 'low' then 'insufficient evidence'
        when scored.adjusted_pace_advantage_pct > 0.1
            and scored.qualifying_win_rate_lower_95 > 0.5 then 'faster than typical teammate'
        when scored.adjusted_pace_advantage_pct < -0.1
            and scored.qualifying_win_rate_upper_95 < 0.5 then 'slower than typical teammate'
        else 'not distinguishable'
    end as verdict,
    row_number() over (
        order by
            case scored.trust_tier when 'high' then 1 when 'medium' then 2 else 3 end,
            scored.adjusted_pace_advantage_pct desc nulls last,
            scored.driver_id
    ) as rank_within_trust
from scored
inner join {{ ref('dim_drivers') }} as drivers
    on scored.driver_id = drivers.driver_id
