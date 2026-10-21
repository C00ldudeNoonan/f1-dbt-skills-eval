{#
    mart_alt_points_standings has one row for every driver with a Grand Prix result in a season.
#}
with expected as (

    select distinct season, driver_id
    from {{ ref('fct_results') }}

),

actual as (

    select season, driver_id
    from {{ ref('mart_alt_points_standings') }}

)

select expected.season, expected.driver_id
from expected
left join actual
    on expected.season = actual.season
    and expected.driver_id = actual.driver_id
where actual.driver_id is null
