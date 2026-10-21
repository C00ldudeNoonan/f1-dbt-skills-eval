-- Flags must agree with the official finishing position. Unclassified results have no position.
select result_id
from {{ ref('fct_results') }}
where (is_win and coalesce(finish_position, 0) <> 1)
    or (is_podium and coalesce(finish_position, 99) > 3)
    or (not is_podium and finish_position between 1 and 3)
    or (points < 0)
