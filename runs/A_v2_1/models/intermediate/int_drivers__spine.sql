-- Every driver_id the warehouse knows about: real driver records, plus any id
-- that appears in a results-type feed before its driver record has arrived
-- (late-arriving rookies and reserves). Ids that only exist in the feeds are
-- flagged as placeholders and get real values automatically once DRIVERS has them.
with drivers as (

    select driver_id from {{ ref('stg_ergast__drivers') }}

),

feed_driver_ids as (

    select driver_id from {{ ref('stg_ergast__results') }}
    union
    select driver_id from {{ ref('stg_ergast__sprint_results') }}
    union
    select driver_id from {{ ref('stg_ergast__qualifying') }}
    union
    select driver_id from {{ ref('stg_ergast__driver_standings') }}

)

select driver_id, false as is_placeholder
from drivers

union all

select driver_id, true as is_placeholder
from feed_driver_ids
where driver_id not in (select driver_id from drivers)
