-- Grain: one row per driver. Does the driver beat teammates in the SAME car? That is the only fair way to
-- separate driver from car in this data, so "overperform" here means "consistently faster than the teammates they
-- were given", measured in percent of lap time.
--
--   edge_pct               mean qualifying advantage over teammates (POSITIVE = faster than teammates), measured
--                          in the latest session both reached. The primary, cleanest signal.
--   edge_pct_shrunk        the same, shrunk towards zero in proportion to its noise (empirical Bayes), so small
--                          samples cannot top the table. Use this for ranking.
--   pace_edge_pct          the same measured on median green-flag race laps (corroboration, 1996+)
--   adjusted_rating_pct    teammate-quality-adjusted rating (int_driver_teammate_ratings): beating a champion counts
--                          for more than beating a backmarker. Use it to COMPARE drivers; `edge_pct` is what a
--                          driver did against the people actually in their garage. Positive = faster than average.
--   teammate_strength_pct  average rating of the teammates faced (comparison-weighted); high = tough garage
--   verdict                'overperforms'    clearly faster in qualifying (edge > 2 standard errors) AND not
--                                            contradicted by race pace
--                          'underperforms'   clearly slower than teammates (mirror image)
--                          'indistinguishable' effect smaller than the noise
--                          'insufficient_data' fewer than the minimum comparisons / teammates / seasons
-- Only drivers with enough evidence are ranked, and a driver is only ever compared to the people who shared
-- their car: a driver who always had weak teammates looks better than they are (see the analysis write-up).
{% set min_comparisons = var('overperformance_min_qualifying_comparisons', 30) %}
{% set min_teammates = var('overperformance_min_teammates', 2) %}
{% set min_seasons = var('overperformance_min_seasons', 3) %}

with per_driver as (
    select
        driver_id,
        count(qual_delta_pct)::integer as qualifying_comparisons,
        avg(qual_delta_pct) as mean_qual_delta,
        stddev_samp(qual_delta_pct) as sd_qual_delta,
        count(race_pace_delta_pct)::integer as race_pace_comparisons,
        avg(race_pace_delta_pct) as mean_pace_delta,
        stddev_samp(race_pace_delta_pct) as sd_pace_delta,
        count(distinct teammate_id) as teammates,
        count(distinct season) as seasons,
        min(season) as first_season,
        max(season) as last_season
    from {{ ref('int_teammate_pace_deltas') }}
    group by driver_id
),

scored as (
    select
        *,
        -mean_qual_delta as edge_pct,
        sd_qual_delta / sqrt(nullif(qualifying_comparisons, 0)) as se_pct,
        -mean_pace_delta as pace_edge_pct,
        sd_pace_delta / sqrt(nullif(race_pace_comparisons, 0)) as pace_se_pct,
        qualifying_comparisons >= {{ min_comparisons }}
            and teammates >= {{ min_teammates }}
            and seasons >= {{ min_seasons }} as is_eligible
    from per_driver
),

-- variance of true driver effects: observed spread of edges among eligible drivers minus average noise
prior as (
    select greatest(var_pop(edge_pct) - avg(se_pct * se_pct), 0.0001) as tau2
    from scored
    where is_eligible
),

strength as (
    select
        pairs.driver_id,
        sum(pairs.qualifying_comparisons * ratings.rating_pct) / nullif(sum(pairs.qualifying_comparisons), 0) as teammate_strength_pct
    from {{ ref('mart_driver_teammate_pairs') }} as pairs
    inner join {{ ref('int_driver_teammate_ratings') }} as ratings on ratings.driver_id = pairs.teammate_id
    group by pairs.driver_id
),

final as (
    select
        scored.*,
        own.rating_pct as adjusted_rating_pct,
        strength.teammate_strength_pct,
        scored.edge_pct * prior.tau2 / (prior.tau2 + scored.se_pct * scored.se_pct) as edge_pct_shrunk
    from scored
    cross join prior
    left join {{ ref('int_driver_teammate_ratings') }} as own on own.driver_id = scored.driver_id
    left join strength on strength.driver_id = scored.driver_id
)

select
    final.driver_id,
    drivers.first_name,
    drivers.last_name,
    final.first_season::integer as first_season,
    final.last_season::integer as last_season,
    final.seasons::integer as seasons,
    final.teammates::integer as teammates,
    final.qualifying_comparisons,
    final.edge_pct::number(8, 4) as edge_pct,
    final.se_pct::number(8, 4) as se_pct,
    iff(final.is_eligible, final.edge_pct_shrunk, null)::number(8, 4) as edge_pct_shrunk,
    final.adjusted_rating_pct::number(8, 4) as adjusted_rating_pct,
    final.teammate_strength_pct::number(8, 4) as teammate_strength_pct,
    final.race_pace_comparisons,
    final.pace_edge_pct::number(8, 4) as pace_edge_pct,
    case
        when not final.is_eligible then 'insufficient_data'
        when final.edge_pct > 2 * final.se_pct
            and (final.race_pace_comparisons < 15 or final.pace_edge_pct > 0) then 'overperforms'
        when final.edge_pct < -2 * final.se_pct
            and (final.race_pace_comparisons < 15 or final.pace_edge_pct < 0) then 'underperforms'
        else 'indistinguishable'
    end as verdict,
    iff(final.is_eligible, rank() over (partition by final.is_eligible order by final.edge_pct_shrunk desc), null)::integer as rank_among_eligible,
    iff(final.is_eligible, rank() over (partition by final.is_eligible order by final.adjusted_rating_pct desc), null)::integer as rank_adjusted
from final
inner join {{ ref('dim_drivers') }} as drivers on drivers.driver_id = final.driver_id
