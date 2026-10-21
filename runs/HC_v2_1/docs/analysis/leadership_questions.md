# Two questions from leadership

Models: `mart_driver_overperformance`, `mart_driver_season_overperformance`, `int_teammate_comparisons`,
`mart_pit_stop_trend_by_season`, `mart_pit_stop_trend_summary`, `int_pit_stops_circuit_adjusted`. All are built and
tested by `dbt build`.

## 1. Which drivers overperform their car?

**Short answer.** Measured against their own teammate, the drivers with the clearest and most consistent advantage in
the 1994-onward era are Fernando Alonso, Max Verstappen, Charles Leclerc, Lewis Hamilton and Michael Schumacher. The
list is in `mart_driver_overperformance` (era `1994 onward`).

| Driver | Measure | Positions vs teammate, per race | 95% interval | Reliable seasons |
|---|---|---|---|---|
| Alonso | race finish | +2.2 | +1.3 to +3.1 | 18 |
| Verstappen | race finish | +2.4 | +0.9 to +3.9 | 9 |
| Leclerc | race finish | +1.3 | +0.4 to +2.1 | 7 |
| Hamilton | race finish | +0.9 | +0.3 to +1.5 | 18 |
| Schumacher | race finish | +1.3 | +0.3 to +2.3 | 13 |
| Alonso | qualifying | +2.2 | +1.3 to +3.1 | 20 |
| Verstappen | qualifying | +2.7 | +1.1 to +4.3 | 10 |
| Norris | qualifying | +1.9 | +0.8 to +3.1 | 6 |

Positive means the driver finished (or qualified) ahead of the teammate.

**Why the question is misleading.** A driver cannot be measured against "the car", because two drivers share a car.
The only fair baseline is the teammate, so the list says who beats their teammate most, not who beats their car.
A driver looks strong when the teammate is weak or new, so these rankings partly measure teammates. Nothing here adjusts
for teammate quality, and that is the main reason to read the list as a shortlist for review, not a verdict.

**Definitions.**
- A comparison is a pair of drivers in the same car at the same race. The measure is the teammate's position minus the
  driver's, so positive means the driver was ahead.
- Race measure: only pairs where both drivers were classified. A retirement is not counted, because a DNF reflects
  reliability more than the driver.
- Qualifying measure: every pair with a qualifying position. Qualifying is usually the cleaner signal of pace, because it
  is not affected by retirements.
- Season: a driver-season counts when it has at least 8 comparisons.
- Career: a driver is eligible with at least 4 reliable seasons. The mean is the average of season means, and the
  interval uses the spread between seasons. This is more honest than treating every race as independent, because drivers
  in one car are correlated.
- Ranking: by the lower end of the interval, so a clear and consistent advantage ranks above a large but noisy one.

**Limitations.**
- Teammate-relative, not car-relative (see above).
- Two-driver teams only. A driver entered twice for one team in one race (pre-1979) is counted once, at the better finish.
- Positions, not lap times or pace. Finishing position also depends on strategy, incidents and penalties.
- The all-time view (era `all seasons`) includes the 1950s and 1960s, when fields were small and teammates were often
  part-time. Its top places go to drivers with few comparisons in small fields, for example Paul Russo and Hanks. Do not
  use it as the headline.
- Some eligible drivers have very few comparisons per season, so the intervals are wide.

## 2. Are pit stops really getting faster, or is that a myth?

**Short answer.** It is a myth, at least as a trend since the 2014 regulations. Within each circuit, stops were about
0.3 seconds faster on average in 2011 to 2013, then about one second slower from 2014. Since 2014 they have been flat
(slope +0.006 seconds per year). The raw median rose from 22.4 seconds in 2011 to 23.3 seconds in 2024.

| Period | Stable-circuit stops | Mean vs circuit median | Slope (s per year) |
|---|---|---|---|
| 2011 to 2013 | 3,003 | −0.23 s | −0.14 |
| 2014 to 2024 | 7,851 | +0.82 s | +0.006 |
| 2011 to 2024 | 10,854 | +0.53 s | +0.08 |

**Why the question is misleading.** "Faster" is usually argued from record-setting stops, which are the fastest of many
and not typical. The typical stop has not improved. Raw medians also mix in circuits: the calendar changed from season
to season, and pit-lane length differs by circuit, so a raw average can move without any change in the crews.

**Definitions.**
- Stop time: `MILLISECONDS` from the pit stop table, at most 60 seconds (red-flag stoppages excluded), in seconds.
- Adjusted: each stop minus the median stop time at the same circuit over all seasons. Circuits with fewer than 30 stops
  are not stable and are left out of the adjusted figures.
- Trend: the least-squares slope of adjusted stop time on season.

**Limitations.**
- The data gives total pit-lane time, not stationary time. Pit-lane transit depends on circuit layout and on where the
  pit lane is entered, so the adjustment removes that only on average. Crew performance and transit cannot be separated
  here.
- Stops per race and tyre strategy changed over the period (more stops in some years), and a stop's time can depend on
  the work done (tyre changes, front wings). The data does not record the work.
- 2020 had fewer races and a different calendar.
- Stop data starts in 2011, so there is no earlier baseline.
- A few circuits have many stops in one period and few in another, which the circuit adjustment handles only if the
  circuit median is stable.

## Tests and checks

- Teammate comparisons are mirror images with opposite signs (singular test).
- Season reliability uses the 8-comparison rule (unit test). Pairing uses the same race and car only (unit test).
- Each circuit's adjusted median is zero (singular test). The mean is not zero, because stop times have a long slow tail.
- Interval ordering, rank uniqueness and key uniqueness are tested on each mart.

## Reproduce

```bash
dbt build --select mart_driver_overperformance mart_pit_stop_trend_summary
dbt show --inline "select * from {{ ref('mart_driver_overperformance') }} where era = '1994 onward' and rank <= 10"
dbt show --inline "select * from {{ ref('mart_pit_stop_trend_summary') }}"
```
