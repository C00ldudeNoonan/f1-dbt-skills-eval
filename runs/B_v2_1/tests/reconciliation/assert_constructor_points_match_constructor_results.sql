-- Independent cross-check against the vendor's own per-race constructor points
-- table: a team's Grand Prix points in fct_results must equal CONSTRUCTOR_RESULTS
-- for every race from 1979 (until 1978 only a team's best-placed car scored
-- constructors' points) at weekends without a sprint (constructor_results
-- include sprint points).
-- A duplicated team or result row doubles one side and fails this test.
with ours as (
    select race_id, constructor_id, sum(points) as points
    from {{ ref('fct_results') }}
    group by 1, 2
),

vendor as (
    select race_id, constructor_id, sum(points) as points
    from {{ ref('stg_ergast__constructor_results') }}
    group by 1, 2
)

select ours.race_id, ours.constructor_id, ours.points as our_points, vendor.points as vendor_points
from ours
inner join vendor
    on ours.race_id = vendor.race_id
    and ours.constructor_id = vendor.constructor_id
inner join {{ ref('stg_ergast__races') }} as races
    on ours.race_id = races.race_id
where races.season >= 1979
    and not races.has_sprint
    and ours.points <> vendor.points
