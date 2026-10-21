-- Every race on the calendar of a complete season has at least one result.
select races.race_id
from {{ ref('stg_ergast__races') }} as races
inner join {{ ref('int_season_status') }} as season_status on races.season = season_status.season
left join {{ ref('fct_results') }} as results on races.race_id = results.race_id
where season_status.is_season_complete
group by races.race_id
having count(results.result_id) = 0
