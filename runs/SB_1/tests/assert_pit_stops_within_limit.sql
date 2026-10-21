-- Red-flag stoppages (> 60s) must never leak into the pit-stop mart.
select * from {{ ref('mart_constructor_season_pit_stops') }}
where median_pit_stop_seconds > 60
