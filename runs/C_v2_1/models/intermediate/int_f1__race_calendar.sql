-- One row per Grand Prix on the calendar, flagged with whether it has been
-- run (has results) and whether its season is complete. This is the single
-- definition of "completed round" and "completed season" for the project.

with races as (
    select * from {{ ref('stg_f1__races') }}
),

races_with_results as (
    select distinct race_id
    from {{ ref('stg_f1__results') }}
),

flagged as (
    select
        races.race_id,
        races.season,
        races.round,
        races.circuit_id,
        races.race_name,
        races.race_date,
        races.has_sprint,
        races_with_results.race_id is not null as is_completed
    from races
    left join races_with_results
        on races.race_id = races_with_results.race_id
)

select
    *,
    -- A season counts as complete only when every race on its calendar has results.
    booland_agg(is_completed) over (partition by season) as is_season_complete,
    is_completed
        and round = max(case when is_completed then round end) over (partition by season)
        as is_latest_completed_round
from flagged
