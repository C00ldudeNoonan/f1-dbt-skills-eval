-- Fan-out guard: a bad join (e.g. duplicated dimension rows) inflates a team's wins/points while the
-- table still looks healthy. Totals must equal raw, per constructor, regardless of cause.
with raw_totals as (

    select constructor_id, count(*) as entries, sum(points) as points, count_if(finish_position = 1) as wins
    from {{ ref('stg_f1__results') }}
    group by constructor_id

),

mart_totals as (

    select constructor_id, count(*) as entries, sum(points) as points, count_if(is_win) as wins
    from {{ ref('fct_results') }}
    group by constructor_id

)

select raw_totals.constructor_id
from raw_totals
full outer join mart_totals using (constructor_id)
where raw_totals.entries is distinct from mart_totals.entries
    or raw_totals.points is distinct from mart_totals.points
    or raw_totals.wins is distinct from mart_totals.wins
