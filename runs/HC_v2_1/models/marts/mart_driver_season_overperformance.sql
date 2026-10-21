{#
    How each driver did against their teammate, per season and measure. positions_gained is averaged over the
    comparisons in the season. A season counts only with at least 8 comparisons (is_reliable).

    lower_95 and upper_95 are a 95% interval for the mean, using the standard error of the comparisons. Comparisons
    within one race and car are not fully independent, so the interval is optimistic. The career view (see
    mart_driver_overperformance) uses a season-level interval, which is more honest.
#}
with comparisons as (

    select * from {{ ref('int_teammate_comparisons') }}

)

select
    measure,
    season,
    driver_id,
    count(*) as comparisons,
    count(distinct teammate_id) as teammates,
    round(avg(positions_gained), 3) as mean_positions_gained,
    round(stddev_samp(positions_gained), 3) as stddev_positions_gained,
    round(avg(positions_gained) - 1.96 * stddev_samp(positions_gained) / sqrt(count(*)), 3) as lower_95,
    round(avg(positions_gained) + 1.96 * stddev_samp(positions_gained) / sqrt(count(*)), 3) as upper_95,
    count(*) >= 8 as is_reliable
from comparisons
group by measure, season, driver_id
