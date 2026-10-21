-- Anchor the standings mart to official championship history.
select
    season,
    driver_id
from {{ ref('mart_driver_season_standings') }}
where championship_position = 1
    and is_season_complete
    and (
        (season = 1950 and driver_id <> (select driver_id from {{ ref('stg_f1__drivers') }} where driver_ref = 'farina'))
        or (season = 2008 and driver_id <> (select driver_id from {{ ref('stg_f1__drivers') }} where driver_ref = 'hamilton'))
        or (season = 2016 and driver_id <> (select driver_id from {{ ref('stg_f1__drivers') }} where driver_ref = 'rosberg'))
        or (season = 2021 and driver_id <> (select driver_id from {{ ref('stg_f1__drivers') }} where driver_ref = 'max_verstappen'))
    )
