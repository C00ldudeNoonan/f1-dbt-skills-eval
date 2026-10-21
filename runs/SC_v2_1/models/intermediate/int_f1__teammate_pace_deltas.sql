-- One row per race, constructor and ordered teammate pair: difference in median green-flag lap
-- time (negative = `driver_id` faster), from fct_driver_race_pace. Both drivers need at least
-- min_green_laps clean laps, and pairs further apart than max_abs_delta_pct are dropped (damage,
-- a long stint on the wrong tyre, partial-race pace). Race results are deliberately not used:
-- they mix in reliability, strategy and luck, whereas lap time against the same-car teammate
-- is as close to "driver vs car" as this data gets.
{% set min_green_laps = 15 %}
{% set max_abs_delta_pct = 3 %}

with entries as (

    select
        pace.race_id,
        results.constructor_id,
        pace.driver_id,
        pace.median_green_lap_ms
    from {{ ref('fct_driver_race_pace') }} as pace
    inner join (
        -- one constructor per driver per race (shared drives predate lap data)
        select distinct race_id, driver_id, constructor_id from {{ ref('fct_results') }}
    ) as results
        on results.race_id = pace.race_id
        and results.driver_id = pace.driver_id
    where pace.green_laps >= {{ min_green_laps }}

)

select
    a.race_id,
    races.season,
    a.constructor_id,
    a.driver_id,
    b.driver_id as teammate_id,
    (100 * ln(a.median_green_lap_ms::double / b.median_green_lap_ms))::double as delta_pct
from entries as a
inner join entries as b
    on a.race_id = b.race_id
    and a.constructor_id = b.constructor_id
    and a.driver_id <> b.driver_id
inner join {{ ref('stg_f1__races') }} as races on races.race_id = a.race_id
where abs(100 * ln(a.median_green_lap_ms::double / b.median_green_lap_ms)) <= {{ max_abs_delta_pct }}
