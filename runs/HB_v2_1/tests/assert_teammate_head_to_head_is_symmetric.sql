{#
    Each pair appears in both orderings with identical race counts, and
    "ahead" counts never exceed the races they were measured in.
#}
with pairs as (

    select *
    from {{ ref('mart_teammate_head_to_head') }}

),

mirrored as (

    select
        a.season,
        a.constructor_id,
        a.driver_id,
        a.teammate_id,
        a.races_together,
        a.races_ahead,
        a.qualifying_together,
        a.qualifying_ahead,
        b.races_together as mirror_races_together,
        b.qualifying_together as mirror_qualifying_together

    from pairs as a
    left join pairs as b
        on a.season = b.season
        and a.constructor_id = b.constructor_id
        and a.driver_id = b.teammate_id
        and a.teammate_id = b.driver_id

)

select *
from mirrored
where mirror_races_together is null
    or mirror_races_together <> races_together
    or mirror_qualifying_together <> qualifying_together
    or races_together < 1
    or races_ahead > races_together
    or qualifying_ahead > qualifying_together
