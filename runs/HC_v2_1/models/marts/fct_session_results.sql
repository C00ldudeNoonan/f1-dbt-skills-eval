{#
    One row per result entry across Grand Prix and sprint sessions. The key is (session_type, source_result_id),
    because the two source tables have separate RESULTID sequences.

    fct_results is the Grand Prix view. This model is the union used for session-level analysis.
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
        points,
        laps,
        status,
        is_win,
        is_podium
    from {{ ref('fct_results') }}

),

sprints as (

    select
        sprint_results.result_id,
        sprint_results.race_id,
        sprint_results.driver_id,
        sprint_results.constructor_id,
        sprint_results.grid,
        {{ classified_finish_position('sprint_results.position', 'sprint_results.position_text') }} as finish_position,
        sprint_results.position_order,
        sprint_results.points,
        sprint_results.laps,
        sprint_results.status_id
    from {{ ref('stg_f1__sprint_results') }} as sprint_results

),

sprint_entries as (

    select
        'sprint' as session_type,
        sprints.result_id as source_result_id,
        sprints.race_id,
        races.season,
        races.round,
        races.race_date,
        sprints.driver_id,
        sprints.constructor_id,
        sprints.grid,
        sprints.finish_position,
        sprints.position_order,
        sprints.points,
        sprints.laps,
        status.status_name as status,
        coalesce(sprints.finish_position = 1, false) as is_win,
        coalesce(sprints.finish_position <= 3, false) as is_podium
    from sprints
    inner join {{ ref('stg_f1__races') }} as races
        on sprints.race_id = races.race_id
    left join {{ ref('stg_f1__status') }} as status
        on sprints.status_id = status.status_id

)

select * from grand_prix
union all
select * from sprint_entries
