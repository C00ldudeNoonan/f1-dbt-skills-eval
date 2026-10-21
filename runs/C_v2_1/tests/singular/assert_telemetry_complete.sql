{{ config(severity='warn') }}

-- fct_telemetry should hold one row per raw sample. Both counts come from
-- table metadata, so this costs nothing. A difference has two causes, which
-- can't be told apart without a full scan, hence a warning:
--   * raw has more rows because the vendor resent samples (fct_telemetry keeps
--     the latest copy, so that's fine), or
--   * samples were missed because they landed with a _LOADED_AT older than the
--     lookback window (raise telemetry_lookback_minutes and run
--     `dbt build --select fct_telemetry+ --full-refresh`).
select
    (select count(*) from {{ source('telemetry', 'car_telemetry') }}) as raw_samples,
    (select count(*) from {{ ref('fct_telemetry') }}) as fact_samples
where (select count(*) from {{ source('telemetry', 'car_telemetry') }})
    <> (select count(*) from {{ ref('fct_telemetry') }})
