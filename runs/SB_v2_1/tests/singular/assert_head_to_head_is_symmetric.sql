-- Each (driver, teammate) row needs a mirrored (teammate, driver) row with the same races_together,
-- and ahead counts can never exceed the number of races compared.
select a.*
from {{ ref('mart_teammate_head_to_head') }} as a
left join {{ ref('mart_teammate_head_to_head') }} as b
    on a.season = b.season
    and a.constructor_id = b.constructor_id
    and a.driver_id = b.teammate_id
    and a.teammate_id = b.driver_id
where b.driver_id is null
   or a.races_together <> b.races_together
   or a.qualifying_together <> b.qualifying_together
   or a.races_ahead + b.races_ahead > a.races_together
   or a.qualifying_ahead + b.qualifying_ahead > a.qualifying_together
