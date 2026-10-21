-- Every season that has started must have exactly one latest completed round,
-- otherwise standings would be duplicated or missing for that season.
select
    season,
    count_if(is_latest_completed_round) as latest_rounds
from {{ ref('int_f1__race_calendar') }}
group by season
having count_if(is_completed) > 0
    and count_if(is_latest_completed_round) <> 1
