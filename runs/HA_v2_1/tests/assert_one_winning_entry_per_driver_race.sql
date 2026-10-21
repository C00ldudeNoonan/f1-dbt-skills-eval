{#
    A driver's win in a race is counted once. Two winning rows for the same driver in the same
    race means one result was counted twice.

    Several races share a win between two drivers (for example 1951 French GP, 1956 Argentine GP,
    1957 British GP), and the feed lists both as 1st. Those are two drivers, so they pass here.
#}
select race_id, driver_id, count(*) as winning_rows
from {{ ref('fct_results') }}
where is_win
group by race_id, driver_id
having count(*) > 1
