-- Cross-source reconciliation: for every Grand Prix weekend since 1991, the
-- points a constructor's cars scored in fct_session_results (Grand Prix plus
-- sprint) must equal the vendor's separate constructor_results table. Inflated
-- or missing fact rows for any team (duplicated Ferrari results, a replayed
-- batch) break this even when every key looks unique.

with fact_points as (
    select
        race_id,
        constructor_id,
        sum(points) as points
    from {{ ref('fct_session_results') }}
    where season >= 1991
    group by race_id, constructor_id
),

vendor_points as (
    select
        constructor_results.race_id,
        constructor_results.constructor_id,
        constructor_results.points
    from {{ ref('stg_f1__constructor_results') }} as constructor_results
    inner join {{ ref('int_f1__race_calendar') }} as calendar
        on constructor_results.race_id = calendar.race_id
    where calendar.season >= 1991
)

select
    coalesce(fact_points.race_id, vendor_points.race_id) as race_id,
    coalesce(fact_points.constructor_id, vendor_points.constructor_id) as constructor_id,
    fact_points.points as fact_points,
    vendor_points.points as vendor_points
from fact_points
full outer join vendor_points
    on fact_points.race_id = vendor_points.race_id
    and fact_points.constructor_id = vendor_points.constructor_id
where coalesce(fact_points.points, 0) <> coalesce(vendor_points.points, 0)
