{#
    Which drivers beat their car. Measured against their own teammate: both drove the same car,
    so the gap in finishing position is the driver's contribution relative to the car.

    mean_race_gap: average positions gained over the teammate per race (positive = ahead).
    lower_95 / upper_95: 95% bounds on that mean (normal approximation, sd / sqrt(n)).
    A driver is listed only if they have at least 30 race pairs over at least 3 seasons.
    Ranking is by lower_95, so a driver ranks high only when the evidence is strong, not when a
    small sample happens to look good.

    Not adjusted for grid or for reliability: DNFs are excluded from each pair, because both
    entries must be classified.
#}
{{ config(materialized='table') }}

with gaps as (

    select * from {{ ref('int_teammate_race_gaps') }}

),

per_driver as (

    select
        driver_id,
        count(*) as race_pairs,
        count(distinct season) as seasons,
        count(distinct teammate_id) as teammates,
        min(season) as first_season,
        max(season) as last_season,
        avg(race_gap) as mean_race_gap,
        stddev_samp(race_gap) as sd_race_gap,
        avg(quali_gap) as mean_quali_gap,
        count(quali_gap) as quali_pairs

    from gaps
    group by driver_id

),

bounds as (

    select
        *,
        mean_race_gap - 1.96 * sd_race_gap / sqrt(race_pairs) as lower_95,
        mean_race_gap + 1.96 * sd_race_gap / sqrt(race_pairs) as upper_95

    from per_driver

)

select
    bounds.driver_id,
    drivers.driver_ref,
    bounds.race_pairs,
    bounds.seasons,
    bounds.teammates,
    bounds.first_season,
    bounds.last_season,
    bounds.mean_race_gap,
    bounds.lower_95,
    bounds.upper_95,
    bounds.mean_quali_gap,
    bounds.quali_pairs,
    (bounds.race_pairs >= 30 and bounds.seasons >= 3) as is_ranked,
    case
        when bounds.race_pairs >= 30 and bounds.seasons >= 3
        then row_number() over (
            partition by (bounds.race_pairs >= 30 and bounds.seasons >= 3)
            order by bounds.lower_95 desc nulls last, bounds.driver_id
        )
    end as rank_by_lower_95

from bounds
inner join {{ ref('stg_f1__drivers') }} as drivers
    on bounds.driver_id = drivers.driver_id
