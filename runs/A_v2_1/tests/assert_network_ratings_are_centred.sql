-- Network ratings are defined relative to the average driver in each connected
-- teammate network: the comparison-weighted mean rating must be ~0 per signal
-- and network. A failure means the least-squares constraint was not applied.
with weights as (

    select signal, driver_id, sum(comparisons) as comparisons
    from {{ ref('int_driver_teammate_pairs') }}
    group by 1, 2

)

select
    ratings.signal,
    ratings.component_id,
    sum(ratings.rating_pct * weights.comparisons) / sum(weights.comparisons) as weighted_mean_rating
from {{ ref('int_driver_network_ratings') }} as ratings
inner join weights
    on ratings.signal = weights.signal
    and ratings.driver_id = weights.driver_id
group by 1, 2
having abs(sum(ratings.rating_pct * weights.comparisons) / sum(weights.comparisons)) > 1e-6
