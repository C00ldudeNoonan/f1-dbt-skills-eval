-- Grand Prix and sprint entries in one table. Ids are only unique within a session
-- type, so the key is (session_type, source_result_id).
with race_results as (

    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        season,
        round,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        points
    from {{ ref('fct_results') }}

),

sprint_results as (

    select
        'sprint' as session_type,
        sprints.result_id as source_result_id,
        sprints.race_id,
        races.season,
        races.round,
        sprints.driver_id,
        sprints.constructor_id,
        sprints.grid,
        sprints.finish_position,
        sprints.points
    from {{ ref('stg_f1__sprint_results') }} as sprints
    inner join {{ ref('stg_f1__races') }} as races on races.race_id = sprints.race_id

)

select * from race_results
union all
select * from sprint_results
