{#
    Calendar spine the Semantic Layer uses for time-based metrics and time grains. One row per day.
    The range covers every race date in the raw data with room to spare for future seasons.
#}
{{ dbt_utils.date_spine(
    datepart='day',
    start_date="cast('1940-01-01' as date)",
    end_date="cast('2035-01-01' as date)"
) }}
