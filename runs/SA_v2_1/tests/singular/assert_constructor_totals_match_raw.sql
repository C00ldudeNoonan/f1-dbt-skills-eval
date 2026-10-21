-- Per-constructor wins and points in fct_results must equal the staged results (fan-out check
-- at the level the dashboards read).
select coalesce(f.constructor_id, s.constructor_id) as constructor_id, f.wins, s.wins as staged_wins, f.points, s.points as staged_points
from (
    select constructor_id, count_if(is_win) as wins, sum(points) as points from {{ ref('fct_results') }} group by constructor_id
) as f
full outer join (
    select constructor_id, count_if(finish_position = 1) as wins, sum(points) as points from {{ ref('stg_ergast__results') }} group by constructor_id
) as s on f.constructor_id = s.constructor_id
where f.wins is distinct from s.wins or f.points is distinct from s.points
