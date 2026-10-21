-- One row per day for the Semantic Layer (MetricFlow joins metrics to it for
-- time-based grouping). Starts with the first championship season and runs
-- to the end of next year, so every race date is covered.

{{ config(materialized='table') }}

with days as (
    select
        dateadd(day, seq4(), '1950-01-01'::date) as date_day
    from table(generator(rowcount => 40000))
)

select date_day
from days
where date_day < date_from_parts(year(current_date()) + 2, 1, 1)
