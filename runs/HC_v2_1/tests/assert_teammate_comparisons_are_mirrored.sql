{#
    Every comparison must have a mirror image for the teammate, with the opposite positions_gained. If a pair is missing or
    the sign is wrong, the driver averages are biased.
#}
select
    a.measure,
    a.race_id,
    a.driver_id,
    a.teammate_id
from {{ ref('int_teammate_comparisons') }} as a
left join {{ ref('int_teammate_comparisons') }} as b
    on a.measure = b.measure
    and a.race_id = b.race_id
    and a.driver_id = b.teammate_id
    and a.teammate_id = b.driver_id
where b.driver_id is null
    or a.positions_gained <> -b.positions_gained
