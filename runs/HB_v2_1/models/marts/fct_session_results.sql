{#
    One row per driver entry in every race session: Grand Prix ('race') and sprint
    ('sprint'). source_result_id is the id in the source table for that session type,
    so (session_type, source_result_id) is the key.

    Finish rules match fct_results: finish_position is null when unclassified.
#}
with grand_prix as (

    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        season,
        round,
        race_date,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_order,
        points

    from {{ ref('fct_results') }}

),

sprints as (

    select
        'sprint' as session_type,
        sprint_results.sprint_result_id as source_result_id,
        races.race_id,
        races.season,
        races.round,
        races.race_date,
        sprint_results.driver_id,
        sprint_results.constructor_id,
        sprint_results.grid,
        coalesce(
            sprint_results.position,
            {{ position_text_to_int('sprint_results.position_text') }}
        ) as finish_position,
        sprint_results.position_order,
        sprint_results.points

    from {{ ref('stg_f1__sprint_results') }} as sprint_results
    inner join {{ ref('stg_f1__races') }} as races
        on sprint_results.race_id = races.race_id

),

combined as (

    select * from grand_prix
    union all
    select * from sprints

)

select
    session_type,
    source_result_id,
    race_id,
    season,
    round,
    race_date,
    driver_id,
    constructor_id,
    grid,
    finish_position,
    position_order,
    points,
    finish_position is not null as is_classified,
    coalesce(finish_position = 1, false) as is_win,
    coalesce(finish_position between 1 and 3, false) as is_podium

from combined
