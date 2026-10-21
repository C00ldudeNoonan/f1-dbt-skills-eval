-- One row per Grand Prix with pit stop data (2011 onwards): how long cars
-- spent in the pit lane, compared with that circuit's own norm.
--
-- What the data measures: pit_stops.duration is pit-lane time, from the
-- pit-entry to the pit-exit timing line. It includes driving the pit lane at
-- the speed limit, so it depends mostly on the circuit (pit-lane length) and
-- the speed-limit rules. It does not record the stationary time (the
-- 2-3 seconds the crew works on the car), which is what "faster pit stops"
-- usually means.
--
-- Rules regime: pit-lane times jump by about 2.5s at most circuits between
-- the 2013 German and Hungarian Grands Prix, consistent with the lower
-- pit-lane speed limit introduced mid-2013. Stops before the change aren't
-- comparable with later ones. The circuit baseline is computed after the
-- change only (var `pit_regime_start_date`, default 2013-07-28, the 2013
-- Hungarian GP).
--
-- Stops over 60s (red flags) are excluded. p10_seconds (the 10th percentile)
-- tracks the quickest, clean stops. The median also includes slow stops for
-- repairs and drive-through penalties, which can't be told apart in the data.

{% set regime_start = var('pit_regime_start_date', '2013-07-28') %}

with stops as (
    select
        races.race_id,
        races.season,
        races.round,
        races.race_date,
        races.circuit_id,
        pit_stops.duration_ms / 1000.0 as seconds
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join {{ ref('stg_f1__races') }} as races
        on pit_stops.race_id = races.race_id
    where pit_stops.duration_ms <= 60000
),

per_race as (
    select
        race_id,
        season,
        round,
        race_date,
        circuit_id,
        race_date >= '{{ regime_start }}'::date as is_current_regime,
        count(*) as stops,
        median(seconds) as median_seconds,
        percentile_cont(0.1) within group (order by seconds) as p10_seconds
    from stops
    group by race_id, season, round, race_date, circuit_id
),

circuit_baseline as (
    select
        circuit_id,
        count(*) as baseline_races,
        median(median_seconds) as baseline_median_seconds,
        median(p10_seconds) as baseline_p10_seconds
    from per_race
    where is_current_regime
    group by circuit_id
)

select
    per_race.race_id,
    per_race.season,
    per_race.round,
    per_race.race_date,
    per_race.circuit_id,
    circuits.circuit_name,
    per_race.is_current_regime,
    per_race.stops,
    per_race.median_seconds::number(8, 3) as median_seconds,
    per_race.p10_seconds::number(8, 3) as p10_seconds,
    circuit_baseline.baseline_races,
    circuit_baseline.baseline_median_seconds::number(8, 3) as circuit_baseline_median_seconds,
    (per_race.median_seconds - circuit_baseline.baseline_median_seconds)::number(8, 3) as median_vs_circuit_seconds,
    (per_race.p10_seconds - circuit_baseline.baseline_p10_seconds)::number(8, 3) as p10_vs_circuit_seconds
from per_race
inner join {{ ref('stg_f1__circuits') }} as circuits
    on per_race.circuit_id = circuits.circuit_id
left join circuit_baseline
    on per_race.circuit_id = circuit_baseline.circuit_id
