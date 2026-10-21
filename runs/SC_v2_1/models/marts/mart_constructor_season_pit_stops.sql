{#- Stops over this many ms are red-flag stoppages, not real pit stops. -#}
{% set max_pit_stop_ms = 60000 %}

with pit_stops as (

    select * from {{ ref('stg_f1__pit_stops') }}
    where duration_ms <= {{ max_pit_stop_ms }}

),

-- A driver can appear on two result rows in a race only in the early shared-drive
-- era, which predates pit stop data, so (race, driver) resolves to one constructor.
entries as (

    select distinct race_id, driver_id, constructor_id, season
    from {{ ref('fct_results') }}

)

select
    entries.season,
    entries.constructor_id,
    count(*)::integer as pit_stop_count,
    (median(pit_stops.duration_ms) / 1000.0)::number(12, 4) as median_pit_stop_seconds
from pit_stops
inner join entries
    on entries.race_id = pit_stops.race_id
    and entries.driver_id = pit_stops.driver_id
group by entries.season, entries.constructor_id
