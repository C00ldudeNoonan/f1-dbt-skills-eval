-- Rounds should be completed in calendar order. A gap (round 5 has results
-- but round 4 does not) would mean a load problem and would make
-- "as of the latest completed round" misleading.
with calendar as (
    select
        *,
        max(case when is_completed then round end) over (partition by season) as max_completed_round
    from {{ ref('int_f1__race_calendar') }}
)

select *
from calendar
where not is_completed
    and round < max_completed_round
