{#
    Grain: one row per Grand Prix result entry (result_id). Sprints are excluded;
    they live in stg_f1__sprint_results.
    finish_position is null when the driver was not classified (retired,
    disqualified, excluded, withdrew, failed to qualify, not classified).
    Classified finishers are read from position_text, because the raw position
    column is null for some lapped finishers that still have a classified rank.
    is_orphan_driver is true when the driver has no record in the drivers feed yet. The
    row is kept, and dim_drivers carries a placeholder for that driver until the record arrives.
#}
with results as (

    select * from {{ ref('stg_f1__results') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

constructors as (

    select * from {{ ref('stg_f1__constructors') }}

),

status as (

    select * from {{ ref('stg_f1__status') }}

),

orphan_drivers as (

    select driver_id from {{ ref('int_orphan_driver_ids') }}

),

final as (

    select
        results.result_id,
        results.race_id,
        races.season,
        races.round,
        races.race_date,
        results.driver_id,
        results.constructor_id,
        constructors.constructor_name,
        results.grid,
        case
            when results.position_text rlike '^[0-9]+$'
                then results.position_text::int
        end as finish_position,
        results.position_order,
        results.points,
        results.laps,
        status.status,
        results.fastest_lap_time_ms,
        orphan_drivers.driver_id is not null as is_orphan_driver
    from results
    inner join races
        on results.race_id = races.race_id
    left join constructors
        on results.constructor_id = constructors.constructor_id
    left join status
        on results.status_id = status.status_id
    left join orphan_drivers
        on results.driver_id = orphan_drivers.driver_id

)

select
    *,
    coalesce(finish_position = 1, false) as is_win,
    coalesce(finish_position <= 3, false) as is_podium
from final
