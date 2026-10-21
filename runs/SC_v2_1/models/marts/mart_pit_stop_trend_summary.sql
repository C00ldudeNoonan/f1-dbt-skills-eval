-- One row per period: the straight-line trend of the chain-linked pit lane time index
-- (index points per year; negative would mean pit stops getting faster) with its standard error,
-- plus the change between the first and last season of the period. Few points, so read the
-- interval, not just the slope. See docs/analysis.
{% set periods = [('2011-2024', 2011, 2024), ('2011-2021', 2011, 2021), ('2014-2024', 2014, 2024)] %}

with trend as (

    select * from {{ ref('mart_pit_stop_trend_by_season') }}

)

{% for label, first_season, last_season in periods %}
{% if not loop.first %}union all{% endif %}
select
    '{{ label }}' as period,
    {{ first_season }} as first_season,
    {{ last_season }} as last_season,
    count(*)::integer as seasons,
    regr_slope(chained_index, season)::double as index_points_per_year,
    (sqrt(
        greatest(regr_syy(chained_index, season) - regr_slope(chained_index, season) * regr_sxy(chained_index, season), 0)
        / nullif(count(*) - 2, 0)
        / regr_sxx(chained_index, season)
    ))::double as standard_error,
    (max(iff(season = {{ last_season }}, chained_index, null))
        / max(iff(season = {{ first_season }}, chained_index, null)) - 1) * 100 as change_first_to_last_pct
from trend
where season between {{ first_season }} and {{ last_season }}
{% endfor %}
