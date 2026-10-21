-- Pit stops join to results on (race, driver). That must give one result row per driver per race
-- in the pit stop era, otherwise pit stops would be double counted.
select
    season,
    race_id,
    driver_id,
    count(*) as result_rows
from {{ ref('fct_results') }}
where season >= 2011
group by season, race_id, driver_id
having count(*) > 1
