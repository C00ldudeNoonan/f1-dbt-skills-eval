-- Each pairing appears in both orderings with the same number of shared races, and the
-- two "ahead" counts can never exceed the shared races.
select
    a.season, a.constructor_id, a.driver_id, a.teammate_id
from {{ ref('mart_teammate_head_to_head') }} as a
left join {{ ref('mart_teammate_head_to_head') }} as b
    on b.season = a.season
    and b.constructor_id = a.constructor_id
    and b.driver_id = a.teammate_id
    and b.teammate_id = a.driver_id
where b.driver_id is null
    or a.races_together <> b.races_together
    or a.qualifying_together <> b.qualifying_together
    or a.races_ahead + b.races_ahead > a.races_together
    or a.qualifying_ahead + b.qualifying_ahead > a.qualifying_together
