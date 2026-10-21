-- The jointly solved ratings must reproduce the observed teammate gaps far better than no rating at all
-- (guards against a non-converging iteration or a broken edge list) and be centred within each component.
with qualifying_fit as (

    select
        sqrt(sum(edges.n * power(edges.gap - (a.rating_pct - b.rating_pct), 2)) / sum(edges.n)) as rmse,
        sqrt(sum(edges.n * power(edges.gap, 2)) / sum(edges.n)) as raw_rms
    from (
        select driver_id as a, teammate_id as b, avg(gap_pct) as gap, count(*) as n
        from {{ ref('int_teammate_qualifying_gaps') }}
        group by driver_id, teammate_id
    ) as edges
    inner join {{ ref('int_driver_quali_ratings') }} as a on a.driver_id = edges.a
    inner join {{ ref('int_driver_quali_ratings') }} as b on b.driver_id = edges.b

),

centring as (

    select component_id, abs(sum(rating_pct * n_obs) / sum(n_obs)) as off_centre
    from {{ ref('int_driver_quali_ratings') }}
    group by component_id

)

select 'fit' as problem, rmse as value from qualifying_fit where rmse > 0.6 * raw_rms
union all
select 'centring', off_centre from centring where off_centre > 0.01
