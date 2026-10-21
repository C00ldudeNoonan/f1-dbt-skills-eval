-- Drivers referenced by results, qualifying, standings, lap or pit stop data
-- whose record hasn't arrived in raw drivers yet (common with rookies and
-- reserve drivers). One row per missing driver_id. This model is a view on
-- the staging views, so it shows the current state whenever it's queried.
-- dim_drivers uses it to add placeholder rows, so the facts never lose these
-- results. A row disappears once the real driver record lands.

with drivers as (
    select driver_id from {{ ref('stg_f1__drivers') }}
),

races as (
    select race_id, race_date from {{ ref('stg_f1__races') }}
),

driver_references as (
    select race_id, driver_id, 'result' as reference_type from {{ ref('stg_f1__results') }}
    union all
    select race_id, driver_id, 'sprint_result' from {{ ref('stg_f1__sprint_results') }}
    union all
    select race_id, driver_id, 'qualifying' from {{ ref('stg_f1__qualifying') }}
    union all
    select race_id, driver_id, 'standing' from {{ ref('stg_f1__driver_standings') }}
    union all
    select race_id, driver_id, 'pit_stop' from {{ ref('stg_f1__pit_stops') }}
    union all
    select race_id, driver_id, 'lap' from {{ ref('stg_f1__lap_times') }}
),

orphan_references as (
    select driver_references.*
    from driver_references
    left join drivers
        on driver_references.driver_id = drivers.driver_id
    where drivers.driver_id is null
)

select
    orphan_references.driver_id,
    count_if(orphan_references.reference_type = 'result') as orphan_result_count,
    count_if(orphan_references.reference_type = 'sprint_result') as orphan_sprint_result_count,
    count_if(orphan_references.reference_type = 'qualifying') as orphan_qualifying_count,
    count_if(orphan_references.reference_type = 'standing') as orphan_standing_count,
    count_if(orphan_references.reference_type = 'pit_stop') as orphan_pit_stop_count,
    count_if(orphan_references.reference_type = 'lap') as orphan_lap_count,
    min(races.race_date) as first_race_date,
    max(races.race_date) as last_race_date,
    current_timestamp() as checked_at
from orphan_references
left join races
    on orphan_references.race_id = races.race_id
group by orphan_references.driver_id
