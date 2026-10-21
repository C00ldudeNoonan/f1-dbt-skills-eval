{#
    Daily time spine for the Semantic Layer, 1945-01-01 to 2030-12-31. The range covers
    every race in the source (from 1950) with room for the next decade. It is fixed on purpose:
    a rolling window would drop history.
#}
{{ config(materialized='table') }}

select
    dateadd(day, seq4(), to_date('1945-01-01'))::date as date_day

from table(generator(rowcount => 31411))
