-- Grain: one row per Grand Prix result entry (sprints are excluded; see stg_f1__sprint_results).
with results as (
    select
        *,
        -- Classified = numeric POSITION, or a numeric POSITION_TEXT (lapped finishers whose POSITION is
        -- missing, e.g. 2005 Australia). The value comes from POSITION_ORDER because the raw POSITION
        -- is stale after post-race disqualifications (1983 Brazil).
        (position is not null or regexp_like(position_text, '^[0-9]+$')) as is_classified
    from {{ ref('stg_f1__results') }}
),

races as (
    select * from {{ ref('stg_f1__races') }}
),

constructors as (
    select * from {{ ref('stg_f1__constructors') }}
),

statuses as (
    select * from {{ ref('stg_f1__status') }}
)

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
    case when results.is_classified then results.position_order end as finish_position,
    results.position_order,
    results.points,
    results.laps,
    statuses.status,
    coalesce(results.is_classified and results.position_order = 1, false) as is_win,
    coalesce(results.is_classified and results.position_order <= 3, false) as is_podium,
    results.fastest_lap_time_ms
from results
inner join races on races.race_id = results.race_id
inner join constructors on constructors.constructor_id = results.constructor_id
left join statuses on statuses.status_id = results.status_id
