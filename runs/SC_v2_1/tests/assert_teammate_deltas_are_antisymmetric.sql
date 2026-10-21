-- A teammate comparison seen from the other driver must be its exact mirror image.
select 'quali' as model, a.race_id, a.driver_id, a.teammate_id
from {{ ref('int_f1__teammate_quali_deltas') }} as a
left join {{ ref('int_f1__teammate_quali_deltas') }} as b
    on b.race_id = a.race_id and b.constructor_id = a.constructor_id
    and b.driver_id = a.teammate_id and b.teammate_id = a.driver_id
where b.race_id is null or abs(a.delta_pct + b.delta_pct) > 1e-9

union all

select 'pace', a.race_id, a.driver_id, a.teammate_id
from {{ ref('int_f1__teammate_pace_deltas') }} as a
left join {{ ref('int_f1__teammate_pace_deltas') }} as b
    on b.race_id = a.race_id and b.constructor_id = a.constructor_id
    and b.driver_id = a.teammate_id and b.teammate_id = a.driver_id
where b.race_id is null or abs(a.delta_pct + b.delta_pct) > 1e-9
