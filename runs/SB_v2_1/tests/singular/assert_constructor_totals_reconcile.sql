-- Per-constructor points in fct_results must equal the raw staged results (guards against fan-out in
-- any join added to fct_results later).
with staged as (
    select constructor_id, sum(points) as pts, count_if(position_order = 1) as p1 from {{ ref('stg_f1__results') }} group by 1
),
modelled as (
    select constructor_id, sum(points) as pts, count_if(position_order = 1) as p1 from {{ ref('fct_results') }} group by 1
)
select staged.constructor_id, staged.pts as staged_points, modelled.pts as model_points
from staged left join modelled using (constructor_id)
where staged.pts is distinct from modelled.pts or staged.p1 is distinct from modelled.p1
