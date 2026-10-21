{#- Per-driver summary of teammate gaps (gap_pct, negative = faster than the teammate).
    Races within one season against one teammate share a car state and are not independent, so the unit
    of analysis is the (season, teammate) cluster. The mean is weighted by sessions; the standard error is
    cluster-robust: sqrt(sum(n_c^2 * (m_c - mean)^2)) / sum(n_c) * sqrt(k / (k - 1)). The 95% interval uses
    a Student-t multiplier for k - 1 degrees of freedom (small k means wide intervals).
    Output: driver_id, sessions, teammates, clusters, mean_gap_pct, se_pct, ci_low_pct, ci_high_pct. -#}
{% macro teammate_gap_stats(gaps_relation) %}
with clusters as (

    select
        driver_id,
        teammate_id,
        season,
        count(*) as n,
        avg(gap_pct) as m
    from {{ gaps_relation }}
    group by driver_id, teammate_id, season

),

driver_means as (

    select
        driver_id,
        sum(n) as sessions,
        count(distinct teammate_id) as teammates,
        count(*) as k,
        sum(n * m) / sum(n) as mean_gap_pct
    from clusters
    group by driver_id

),

with_se as (

    select
        driver_means.driver_id,
        driver_means.sessions,
        driver_means.teammates,
        driver_means.k as clusters,
        driver_means.mean_gap_pct,
        case
            when driver_means.k > 1 then
                sqrt(sum(power(clusters.n, 2) * power(clusters.m - driver_means.mean_gap_pct, 2)))
                / driver_means.sessions * sqrt(driver_means.k / (driver_means.k - 1))
        end as se_pct
    from driver_means
    inner join clusters on clusters.driver_id = driver_means.driver_id
    group by
        driver_means.driver_id, driver_means.sessions, driver_means.teammates,
        driver_means.k, driver_means.mean_gap_pct

)

select
    *,
    mean_gap_pct - se_pct * t_multiplier as ci_low_pct,
    mean_gap_pct + se_pct * t_multiplier as ci_high_pct
from (
    select
        *,
        case
            when clusters - 1 <= 1 then 12.71
            when clusters - 1 = 2 then 4.30
            when clusters - 1 = 3 then 3.18
            when clusters - 1 = 4 then 2.78
            when clusters - 1 = 5 then 2.57
            when clusters - 1 = 6 then 2.45
            when clusters - 1 = 7 then 2.36
            when clusters - 1 = 8 then 2.31
            when clusters - 1 = 9 then 2.26
            when clusters - 1 <= 14 then 2.18
            when clusters - 1 <= 29 then 2.05
            else 1.96
        end as t_multiplier
    from with_se
)
{% endmacro %}
