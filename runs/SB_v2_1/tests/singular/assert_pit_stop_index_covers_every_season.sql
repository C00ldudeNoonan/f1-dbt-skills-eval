-- Every season with routine pit stops must have a circuit-adjusted index, otherwise the trend silently loses years.
select season from {{ ref('mart_pit_stop_season_trend') }} where circuit_adjusted_index is null
