-- One row per calendar day, required by the dbt Semantic Layer (MetricFlow) to
-- aggregate metrics over time and fill gaps. Covers the whole championship
-- history with room for future seasons.
{{ config(materialized='table') }}

with days as (

    select dateadd(day, seq4(), '1950-01-01'::date) as date_day
    from table(generator(rowcount => 36525))

)

select date_day::date as date_day
from days
where date_day <= '2049-12-31'::date
