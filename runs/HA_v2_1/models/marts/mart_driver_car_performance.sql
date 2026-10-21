{#
    One row per driver: head-to-head record against teammates, from mart_teammate_head_to_head,
    over seasons from overperformance_min_season (2014 on, the hybrid era with one set of regulations).
    "Overperforms their car" is measured against the teammate on the same car in the same races.
    The team's car is held roughly constant, but teammates differ in skill and team status (a team's
    lead driver usually beats the number two), so this is a relative measure, not an absolute car rating.

    race_win_rate: share of shared Grand Prix in which the driver's best finish beat the teammate's.
    qualifying_win_rate: share of shared qualifying sessions in which the driver was ahead.
    The 95% interval is a normal approximation on race_win_rate. A driver is flagged trusted_overperformer
    only when the whole interval is above 50%, and only with at least min_shared_races shared races.
#}
{% set min_shared = 30 %}
with pairs as (

    select
        driver_id,
        season,
        constructor_id,
        teammate_id,
        races_together,
        races_ahead,
        qualifying_together,
        qualifying_ahead
    from {{ ref('mart_teammate_head_to_head') }}
    where season >= {{ var('overperformance_min_season') }}

),

by_driver as (

    select
        driver_id,
        sum(races_together) as shared_races,
        sum(races_ahead) as races_ahead,
        sum(qualifying_together) as shared_qualifying,
        sum(qualifying_ahead) as qualifying_ahead,
        count(distinct season) as seasons,
        count(distinct constructor_id) as constructors
    from pairs
    group by driver_id

),

rates as (

    select
        *,
        races_ahead / nullif(shared_races, 0) as race_win_rate,
        qualifying_ahead / nullif(shared_qualifying, 0) as qualifying_win_rate
    from by_driver

)

select
    driver_id,
    seasons,
    constructors,
    shared_races,
    races_ahead,
    race_win_rate,
    race_win_rate - 1.96 * sqrt(race_win_rate * (1 - race_win_rate) / nullif(shared_races, 0)) as race_win_rate_ci_low,
    race_win_rate + 1.96 * sqrt(race_win_rate * (1 - race_win_rate) / nullif(shared_races, 0)) as race_win_rate_ci_high,
    shared_qualifying,
    qualifying_ahead,
    qualifying_win_rate,
    shared_races >= {{ min_shared }} as is_eligible,
    shared_races >= {{ min_shared }}
        and race_win_rate - 1.96 * sqrt(race_win_rate * (1 - race_win_rate) / nullif(shared_races, 0)) > 0.5
        as trusted_overperformer
from rates
