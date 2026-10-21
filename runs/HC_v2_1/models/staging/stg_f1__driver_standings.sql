{#
    One row per race and driver. The vendor can load the same standings snapshot twice with different surrogate
    IDs (2026-10-21: round 22 arrived 23 times under IDs offset by 100000). Identical copies collapse to one row,
    keeping the lowest source ID. Copies that disagree stay as separate rows, and the unique test on
    (race_id, driver_id) fails the build.
#}
select
    min({{ null_if_sentinel('DRIVERSTANDINGSID') }}::integer) as driver_standings_id,
    {{ null_if_sentinel('RACEID') }}::integer as race_id,
    {{ null_if_sentinel('DRIVERID') }}::integer as driver_id,
    {{ null_if_sentinel('POINTS') }}::numeric(6, 2) as points,
    {{ null_if_sentinel('POSITION') }}::integer as position,
    {{ null_if_sentinel('POSITIONTEXT') }} as position_text,
    {{ null_if_sentinel('WINS') }}::integer as wins
from {{ source('f1_raw', 'DRIVER_STANDINGS') }}
group by
    race_id,
    driver_id,
    points,
    position,
    position_text,
    wins
