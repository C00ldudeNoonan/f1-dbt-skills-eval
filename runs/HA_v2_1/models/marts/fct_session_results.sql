{#
    Grain: one row per driver entry per session (race or sprint), keyed by session_type
    and source_result_id. Grand Prix results come from fct_results; sprint results come
    from stg_f1__sprint_results. finish_position is null when not classified, using the
    same rule as fct_results.
#}
with race_sessions as (

    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        season,
        round,
        driver_id,
        constructor_id,
        finish_position,
        points
    from {{ ref('fct_results') }}

),

sprint_sessions as (

    select
        'sprint' as session_type,
        sprint_results.sprint_result_id as source_result_id,
        sprint_results.race_id,
        races.season,
        races.round,
        sprint_results.driver_id,
        sprint_results.constructor_id,
        case
            when sprint_results.position_text rlike '^[0-9]+$'
                then sprint_results.position_text::int
        end as finish_position,
        sprint_results.points
    from {{ ref('stg_f1__sprint_results') }} as sprint_results
    inner join {{ ref('stg_f1__races') }} as races
        on sprint_results.race_id = races.race_id

)

select * from race_sessions
union all
select * from sprint_sessions
