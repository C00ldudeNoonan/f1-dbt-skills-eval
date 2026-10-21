{#
    A season is complete only when every race on its calendar has at least one result.
    The official champion is only counted for complete seasons, so this model is the one
    place that decides completeness for the rest of the project.
#}
with races as (

    select * from {{ ref('stg_f1__races') }}

),

races_with_results as (

    select distinct race_id from {{ ref('stg_f1__results') }}

),

calendar as (

    select
        races.season,
        races.round,
        races_with_results.race_id is not null as has_results
    from races
    left join races_with_results
        on races.race_id = races_with_results.race_id

)

select
    season,
    count(*) as races_on_calendar,
    count_if(has_results) as races_with_results,
    max(case when has_results then round end) as last_round_with_results,
    count_if(has_results) = count(*) as is_season_complete
from calendar
group by season
