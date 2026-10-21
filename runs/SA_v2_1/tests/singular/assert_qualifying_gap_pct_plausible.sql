{{ config(severity='warn') }}
-- Known source quirk: one 1995 Japanese GP Q1 time is recorded as 16:42.640 (almost certainly a
-- typo for 1:42.640). It is kept as published; this warns if more such rows appear.
select qualify_id, race_id, driver_id, gap_to_pole_pct
from {{ ref('fct_qualifying') }}
where gap_to_pole_pct > 100
