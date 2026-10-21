{#
    Every pair must appear in both orderings with matching shared totals, and a driver
    cannot be ahead in more races than they raced together (ties count as neither).
#}
with pairs as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        races_together,
        races_ahead,
        qualifying_together,
        qualifying_ahead
    from {{ ref('mart_teammate_head_to_head') }}

)

select
    a.season,
    a.constructor_id,
    a.driver_id,
    a.teammate_id
from pairs as a
left join pairs as b
    on a.season = b.season
    and a.constructor_id = b.constructor_id
    and a.driver_id = b.teammate_id
    and a.teammate_id = b.driver_id
where b.driver_id is null
    or a.races_together <> b.races_together
    or a.qualifying_together <> b.qualifying_together
    or a.races_ahead + b.races_ahead > a.races_together
    or a.qualifying_ahead + b.qualifying_ahead > a.qualifying_together
