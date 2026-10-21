{#
    Required by the Semantic Layer for time-based metrics and grouping. One row per day from
    1950-01-01 to about 2032, so every race date falls inside it.
#}
{{ config(materialized='table') }}
select dateadd(day, seq4(), to_date('1950-01-01')) as date_day
from table(generator(rowcount => 30000))
