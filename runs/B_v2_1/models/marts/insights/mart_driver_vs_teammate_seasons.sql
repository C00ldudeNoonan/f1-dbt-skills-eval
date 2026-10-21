{#-
  One row per driver, season, constructor and teammate: how the driver
  compared with that teammate in identical machinery.
-#}
with quali as (
    select
        season, constructor_id, driver_id, teammate_id,
        count(*)                                        as qualifying_comparisons,
        count_if(is_representative)                     as representative_comparisons,
        median(iff(is_representative, gap_pct, null))   as median_qualifying_gap_pct,
        count_if(is_representative and gap_pct < 0)     as qualifying_ahead
    from {{ ref('int_teammate_qualifying_gaps') }}
    group by 1, 2, 3, 4
),

races as (
    select
        season, constructor_id, driver_id, teammate_id,
        count(*)                    as race_comparisons,
        count_if(finished_ahead)    as races_finished_ahead
    from {{ ref('int_teammate_race_comparisons') }}
    group by 1, 2, 3, 4
),

pairs as (
    select season, constructor_id, driver_id, teammate_id from quali
    union
    select season, constructor_id, driver_id, teammate_id from races
)

select
    pairs.season,
    pairs.constructor_id,
    pairs.driver_id,
    pairs.teammate_id,
    coalesce(quali.qualifying_comparisons, 0)       as qualifying_comparisons,
    coalesce(quali.representative_comparisons, 0)   as representative_qualifying_comparisons,
    quali.median_qualifying_gap_pct::number(8, 4)   as median_qualifying_gap_pct,
    coalesce(quali.qualifying_ahead, 0)             as qualifying_ahead,
    coalesce(races.race_comparisons, 0)             as race_comparisons,
    coalesce(races.races_finished_ahead, 0)         as races_finished_ahead
from pairs
left join quali
    on pairs.season = quali.season and pairs.constructor_id = quali.constructor_id
    and pairs.driver_id = quali.driver_id and pairs.teammate_id = quali.teammate_id
left join races
    on pairs.season = races.season and pairs.constructor_id = races.constructor_id
    and pairs.driver_id = races.driver_id and pairs.teammate_id = races.teammate_id
