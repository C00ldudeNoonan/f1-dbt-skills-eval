{#- Joint teammate-comparison rating. Input: a model of ordered teammate pairs with `driver_id`,
    `teammate_id` and `gap_pct` (driver relative to teammate, negative = faster).
    Model: gap(a, b) = c_a - c_b where c is a driver's "slowness" in percent. Drivers who change teams link
    the teammate pairs together, so each rating is measured against the whole connected field, not only
    against one teammate. It is solved by damped Jacobi iteration of the least-squares normal equations
    (c_a <- weighted mean over teammates b of gap(a, b) + c_b, weights = shared sessions, plus a self term),
    then centred to
    zero within each connected component. Components are found by minimum-label propagation. Ratings are
    only comparable within a component_id.
    Output: driver_id, component_id, rating_pct (negative = faster than the component average),
    n_obs (sessions), n_teammates. -#}
{% macro speed_ratings(gaps_relation, iterations=80, label_iterations=40) %}
with edges as (

    select
        driver_id as a,
        teammate_id as b,
        avg(gap_pct) as gap,
        count(*) as n
    from {{ gaps_relation }}
    group by driver_id, teammate_id

),

nodes as (

    select a as driver_id, sum(n) as n_obs, count(*) as n_teammates from edges group by a

),

-- every driver also gets a zero-gap self edge weighted like all of its teammate edges together. It
-- damps the iteration (avoids oscillation) and lets each step read the previous values just once.
pairs as (

    select a, b, gap, n from edges
    union all
    select driver_id, driver_id, 0.0, n_obs from nodes

),

label_0 as (

    select driver_id, driver_id as label from nodes

),

{% for i in range(1, label_iterations + 1) %}
label_{{ i }} as (

    select pairs.a as driver_id, min(prev.label) as label
    from pairs
    inner join label_{{ i - 1 }} as prev on prev.driver_id = pairs.b
    group by pairs.a

),
{% endfor %}

rating_0 as (

    select driver_id, 0.0::float as c from nodes

),

{% for i in range(1, iterations + 1) %}
rating_{{ i }} as (

    select
        pairs.a as driver_id,
        sum(pairs.n * (pairs.gap + prev.c)) / sum(pairs.n) as c
    from pairs
    inner join rating_{{ i - 1 }} as prev on prev.driver_id = pairs.b
    group by pairs.a

),
{% endfor %}

final as (

    select
        rating.driver_id,
        label_{{ label_iterations }}.label as component_id,
        rating.c,
        nodes.n_obs,
        nodes.n_teammates
    from rating_{{ iterations }} as rating
    inner join label_{{ label_iterations }} on label_{{ label_iterations }}.driver_id = rating.driver_id
    inner join nodes on nodes.driver_id = rating.driver_id

)

select
    driver_id,
    component_id,
    c - sum(c * n_obs) over (partition by component_id) / sum(n_obs) over (partition by component_id) as rating_pct,
    n_obs,
    n_teammates
from final
{% endmacro %}
