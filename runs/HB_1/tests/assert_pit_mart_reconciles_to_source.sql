-- Every pit stop of 60 seconds or less must be counted exactly once in the constructor mart.
select
    (select count(*) from {{ ref('stg_f1__pit_stops') }} where duration_ms <= 60000) as source_stops,
    (select sum(pit_stop_count) from {{ ref('mart_constructor_season_pit_stops') }}) as mart_stops
where (select count(*) from {{ ref('stg_f1__pit_stops') }} where duration_ms <= 60000)
    <> (select sum(pit_stop_count) from {{ ref('mart_constructor_season_pit_stops') }})
