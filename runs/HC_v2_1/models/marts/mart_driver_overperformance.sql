{#
    Career view: which drivers beat their teammate most, per measure and era. Two eras:
      - '1994 onward' is the headline. Qualifying data starts in 1994, fields are full and cars are more alike.
      - 'all seasons' includes the 1950s and 1960s, when fields were small, teammates were often part-time and team
        quality varied far more. Treat it as context, not the headline.

    It uses only seasons where the driver had at least 8 comparisons (see mart_driver_season_overperformance), and
    requires at least 4 such seasons. The mean is the average of the season means, and the interval uses the spread
    between seasons, so one good car-season cannot carry the result. rank is among eligible drivers, best first, by the
    lower end of the interval, which favours drivers whose advantage is clear rather than large but noisy.
#}
with eras as (

    select 'all seasons' as era, 1950 as first_year, 2024 as last_year
    union all select '1994 onward', 1994, 2024

),

reliable_seasons as (

    select
        eras.era,
        seasons.*
    from {{ ref('mart_driver_season_overperformance') }} as seasons
    inner join eras
        on seasons.season between eras.first_year and eras.last_year
    where seasons.is_reliable

),

career as (

    select
        era,
        measure,
        driver_id,
        count(*) as reliable_seasons,
        min(season) as first_season,
        max(season) as last_season,
        sum(comparisons) as comparisons,
        avg(mean_positions_gained) as mean_positions_gained,
        stddev_samp(mean_positions_gained) as season_spread
    from reliable_seasons
    group by era, measure, driver_id

),

scored as (

    select
        *,
        mean_positions_gained - 1.96 * season_spread / sqrt(reliable_seasons) as lower_95,
        mean_positions_gained + 1.96 * season_spread / sqrt(reliable_seasons) as upper_95,
        reliable_seasons >= 4 as is_eligible
    from career

)

select
    era,
    measure,
    driver_id,
    first_season,
    last_season,
    reliable_seasons,
    comparisons,
    round(mean_positions_gained, 3) as mean_positions_gained,
    round(lower_95, 3) as lower_95,
    round(upper_95, 3) as upper_95,
    is_eligible,
    iff(is_eligible, rank() over (partition by era, measure, is_eligible order by lower_95 desc), null) as rank
from scored
