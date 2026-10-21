-- Guards the grain of fct_results: joins to dimensions must never add, drop or
-- multiply rows. Compares row count and total points/wins with the staged results.
with fct as (
    select count(*) as n, sum(points) as points, count_if(is_win) as wins, count(distinct result_id) as distinct_ids
    from {{ ref('fct_results') }}
),

stg as (
    select
        count(*) as n,
        sum(results.points) as points,
        count_if(results.finish_position = 1) as wins
    from {{ ref('stg_results') }} as results
    inner join {{ ref('stg_races') }} using (race_id)
)

select fct.*, stg.n as stg_n, stg.points as stg_points, stg.wins as stg_wins
from fct, stg
where fct.n <> stg.n or fct.distinct_ids <> fct.n
   or fct.points <> stg.points or fct.wins <> stg.wins
