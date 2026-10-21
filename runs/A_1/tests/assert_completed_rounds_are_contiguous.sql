-- Rounds with results should form an unbroken run 1..N. A gap would mean a
-- missing load (and would make "latest completed round" misleading).

select *
from {{ ref('int_seasons__completion') }}
where completed_rounds > 0
  and latest_completed_round <> completed_rounds
