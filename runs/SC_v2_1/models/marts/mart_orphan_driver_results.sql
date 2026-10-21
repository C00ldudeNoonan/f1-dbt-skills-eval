-- Monitoring: results whose driver is not (yet) in the raw `drivers` table.
-- Empty when the feed is healthy; sum(orphan_results) is the total orphan count.
select
    results.driver_id,
    count(*)::integer as orphan_results,
    count(distinct results.race_id)::integer as orphan_races,
    min(results.race_date) as first_race_date,
    max(results.race_date) as last_race_date
from {{ ref('fct_results') }} as results
inner join {{ ref('dim_drivers') }} as drivers
    on drivers.driver_id = results.driver_id
where drivers.is_placeholder
group by results.driver_id
