{{ config(severity='warn') }}

-- Guards the main assumption behind the pit-stop trend: races before the
-- mid-2013 speed-limit change are much quicker than the same circuit's later
-- norm, so they must be kept out of the comparison. If this starts warning,
-- the break has disappeared from the data (for example, a vendor restated
-- durations), and the regime split in mart_race_pit_lane_times needs
-- revisiting.
select
    median(median_vs_circuit_seconds) as pre_change_median_vs_circuit_seconds
from {{ ref('mart_race_pit_lane_times') }}
where not is_current_regime
    and baseline_races >= 3
having median(median_vs_circuit_seconds) > -1
