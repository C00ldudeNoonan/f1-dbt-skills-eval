{#
    Gaps are never negative, and in every race with at least one timed entry
    exactly one entry is on pole time (gap of zero).
#}
with timed_races as (

    select race_id
    from {{ ref('fct_qualifying') }}
    group by race_id
    having count(best_time_ms) > 0

),

pole_entries as (

    select
        race_id,
        count_if(gap_to_pole_ms = 0) as pole_entries

    from {{ ref('fct_qualifying') }}
    group by race_id

)

select
    timed_races.race_id,
    pole_entries.pole_entries

from timed_races
inner join pole_entries
    on timed_races.race_id = pole_entries.race_id
where pole_entries.pole_entries < 1

union all

select
    race_id,
    null as pole_entries

from {{ ref('fct_qualifying') }}
where gap_to_pole_ms < 0
