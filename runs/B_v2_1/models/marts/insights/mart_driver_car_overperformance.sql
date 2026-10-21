{#-
  "Which drivers overperform their car?" One row per driver with qualifying
  teammate comparisons from var overperformance_min_season (default 2006)
  onward. Before 2006 the dataset only has qualifying times for some races
  (often 5-15 comparisons per teammate-season), which is too thin to rank on.

  The car's true pace can't be observed, so the teammate (same car, same
  weekend) is the control. The unit of evidence is a driver-teammate-season:
  the median qualifying gap (%) over that season's representative same-session
  comparisons (see int_teammate_qualifying_gaps).

  Teammate-strength adjustment: losing narrowly to a great teammate says more
  than beating a weak one. Each pair-season gap is shifted by the teammate's
  own weighted gap against *their other* teammates. Teammates with no other
  comparisons count as average (0). Negative = faster than an average teammate.

  Confidence: a 95% interval across pair-seasons (each one a sample), which is
  conservative compared with treating every race as independent. Drivers are
  ranked only with >= 50 representative comparisons, >= 3 distinct teammates
  and >= 4 pair-seasons, because a career spent beside one teammate can't
  separate the driver from that teammate.
-#}
{%- set min_comparisons = 50 -%}
{%- set min_teammates = 3 -%}
{%- set min_pair_seasons = 4 -%}
{%- set min_season = var('overperformance_min_season') -%}

with pair_seasons as (
    select *
    from {{ ref('mart_driver_vs_teammate_seasons') }}
    where representative_qualifying_comparisons > 0
        and season >= {{ min_season }}
),

-- Each teammate's strength measured without the driver being rated.
teammate_strength as (
    select
        rated.driver_id,
        rated.teammate_id,
        sum(other.median_qualifying_gap_pct * other.representative_qualifying_comparisons)
            / nullif(sum(other.representative_qualifying_comparisons), 0)     as teammate_strength_pct
    from (select distinct driver_id, teammate_id from pair_seasons) as rated
    inner join pair_seasons as other
        on other.driver_id = rated.teammate_id
        and other.teammate_id <> rated.driver_id
    group by 1, 2
),

adjusted as (
    select
        pair_seasons.*,
        teammate_strength.teammate_strength_pct,
        pair_seasons.median_qualifying_gap_pct
            + coalesce(teammate_strength.teammate_strength_pct, 0)          as adjusted_gap_pct
    from pair_seasons
    left join teammate_strength
        on pair_seasons.driver_id = teammate_strength.driver_id
        and pair_seasons.teammate_id = teammate_strength.teammate_id
),

race_h2h as (
    select driver_id, sum(race_comparisons) as race_comparisons, sum(races_finished_ahead) as races_ahead
    from {{ ref('mart_driver_vs_teammate_seasons') }}
    where season >= {{ min_season }}
    group by driver_id
),

career as (
    select
        driver_id,
        min(season)                                                         as first_season,
        max(season)                                                         as last_season,
        count(distinct teammate_id)                                         as distinct_teammates,
        count(*)                                                            as pair_seasons,
        sum(representative_qualifying_comparisons)                         as qualifying_comparisons,
        sum(qualifying_ahead)                                               as qualifying_ahead,
        sum(median_qualifying_gap_pct * representative_qualifying_comparisons)
            / sum(representative_qualifying_comparisons)                    as raw_gap_pct,
        sum(adjusted_gap_pct * representative_qualifying_comparisons)
            / sum(representative_qualifying_comparisons)                    as adjusted_gap_pct,
        stddev_samp(adjusted_gap_pct)                                       as adjusted_gap_sd,
        sum(iff(teammate_strength_pct is null, 0, representative_qualifying_comparisons))
            / sum(representative_qualifying_comparisons)                    as share_with_teammate_strength
    from adjusted
    group by driver_id
),

scored as (
    select
        career.*,
        adjusted_gap_pct - 1.96 * adjusted_gap_sd / sqrt(pair_seasons)      as adjusted_gap_ci_low,
        adjusted_gap_pct + 1.96 * adjusted_gap_sd / sqrt(pair_seasons)      as adjusted_gap_ci_high,
        coalesce(race_h2h.race_comparisons, 0)                              as race_comparisons,
        coalesce(race_h2h.races_ahead, 0)                                   as races_ahead,
        qualifying_comparisons >= {{ min_comparisons }}
            and distinct_teammates >= {{ min_teammates }}
            and pair_seasons >= {{ min_pair_seasons }}                      as is_rankable
    from career
    left join race_h2h
        on career.driver_id = race_h2h.driver_id
)

select
    scored.driver_id,
    drivers.first_name || ' ' || drivers.last_name                          as driver_name,
    scored.first_season,
    scored.last_season,
    scored.distinct_teammates,
    scored.pair_seasons,
    scored.qualifying_comparisons,
    (100 * scored.qualifying_ahead / scored.qualifying_comparisons)::number(6, 1) as qualifying_h2h_pct,
    scored.raw_gap_pct::number(8, 3)                                        as raw_qualifying_gap_pct,
    scored.adjusted_gap_pct::number(8, 3)                                   as adjusted_qualifying_gap_pct,
    scored.adjusted_gap_ci_low::number(8, 3)                                as adjusted_gap_ci_low,
    scored.adjusted_gap_ci_high::number(8, 3)                               as adjusted_gap_ci_high,
    (100 * scored.share_with_teammate_strength)::number(6, 1)               as pct_comparisons_strength_adjusted,
    scored.race_comparisons,
    iff(scored.race_comparisons > 0, (100 * scored.races_ahead / scored.race_comparisons), null)::number(6, 1)
                                                                            as race_h2h_pct,
    scored.is_rankable,
    iff(scored.is_rankable,
        rank() over (partition by scored.is_rankable order by scored.adjusted_gap_pct), null)
                                                                            as overperformance_rank,
    case
        when not scored.is_rankable then 'insufficient evidence'
        when scored.adjusted_gap_ci_high < 0 then 'faster than teammates'
        when scored.adjusted_gap_ci_low > 0 then 'slower than teammates'
        else 'not distinguishable'
    end                                                                     as verdict
from scored
left join {{ ref('dim_drivers') }} as drivers
    on scored.driver_id = drivers.driver_id
