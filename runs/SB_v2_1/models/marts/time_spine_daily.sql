-- Daily time spine for the Semantic Layer (metric_time). Static range: it must cover every race date
-- (history starts in 1950) and runs to the end of 2035 so new seasons never fall off it.
{{ config(materialized='table') }}

with days as (
    {{ dbt.date_spine('day', "DATE('1950-01-01')", "DATE('2036-01-01')") }}
)

select cast(date_day as date) as date_day
from days
