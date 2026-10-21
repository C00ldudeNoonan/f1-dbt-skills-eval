-- Per-race sample counts must match the raw table. Reads a single column of each table, so it is cheap.
-- A mismatch usually means samples landed with a loaded_at older than our watermark; reload the race with
--   dbt run --select fct_telemetry+ --vars '{telemetry_reload_races: [<race_id>]}'
-- (raw duplicates of a sample key would also show up here).
select
    coalesce(raw.race_id, fct.race_id) as race_id,
    raw.n as raw_samples,
    fct.n as fct_samples
from (select race_id, count(*) as n from {{ ref('stg_telemetry__car_telemetry') }} group by race_id) as raw
full outer join (select race_id, count(*) as n from {{ ref('fct_telemetry') }} group by race_id) as fct
    on raw.race_id = fct.race_id
where raw.n is distinct from fct.n
