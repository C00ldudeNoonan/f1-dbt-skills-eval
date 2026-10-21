{{ config(materialized='table') }}

-- Daily calendar the Semantic Layer needs for time-based metrics (cumulative, offset, gap-filling).
select
    dateadd(day, row_number() over (order by seq4()) - 1, '1950-01-01'::date) as date_day
from table(generator(rowcount => 36525))
