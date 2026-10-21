-- Daily calendar for MetricFlow. Must cover every race date (1950 onward) plus future
-- seasons, so it is deliberately not limited to a rolling window.
{{ config(materialized='table') }}

with base_dates as (

    {{ dbt.date_spine('day', "DATE('1949-01-01')", "DATE('2040-01-01')") }}

)

select cast(date_day as date) as date_day
from base_dates
