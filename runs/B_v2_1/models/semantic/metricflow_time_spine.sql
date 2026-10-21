{#-
  Daily time spine for the dbt Semantic Layer (MetricFlow), covering the whole
  F1 history: 1950-01-01 through the end of next year.
-#}
{{ config(materialized='table') }}

with days as (
    select
        dateadd(day, seq4(), '1950-01-01'::date) as date_day
    from table(generator(rowcount => 40000))
)

select date_day
from days
where date_day <= dateadd(year, 1, date_trunc(year, current_date()))
