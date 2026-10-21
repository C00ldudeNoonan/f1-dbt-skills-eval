# Two leadership questions

Numbers are from the dbt models named in each section, as built on 2026-10-21 (data through the 2024 season; 2024 rounds
23-24 were loaded late, and the raw feed has been revised more than once, so rerun before quoting). Everything below can be
reproduced with `select * from <model>`.

---

## 1. "Which drivers actually overperform their car? I want a list I can trust."

**Short answer.** Ten drivers have a margin over their teammates that is big enough to trust, and four have a trustworthy
deficit. Everyone else is statistically indistinguishable from their teammates, or has too little data to say. The list is
`mart_driver_teammate_performance` (filter `verdict = 'outperforms_teammates'`, order by `rank_among_rated`).

| rank | driver | score (% per lap vs teammates, negative = faster) | 95% interval |
|---|---|---|---|
| 1 | Michael Schumacher | -0.69 | -1.07 to -0.32 |
| 2 | Max Verstappen | -0.48 | -0.68 to -0.27 |
| 4 | Mark Webber | -0.35 | -0.63 to -0.08 |
| 5 | Sebastian Vettel | -0.32 | -0.50 to -0.14 |
| 6 | Lewis Hamilton | -0.31 | -0.36 to -0.25 |
| 8 | Nico Rosberg | -0.29 | -0.53 to -0.06 |
| 10 | Fernando Alonso | -0.23 | -0.33 to -0.13 |
| 13 | Rubens Barrichello | -0.20 | -0.41 to -0.00 (borderline) |
| 16 | Nico Hülkenberg | -0.19 | -0.34 to -0.05 |
| 23 | Carlos Sainz | -0.15 | -0.23 to -0.06 |

(Ranks 3, 7, 9 and others are drivers whose interval includes zero, e.g. Frentzen at #3 and Sato at #7: ranked, but not
trustworthy. Use `verdict`, not rank alone.) Underperforming against teammates with a trustworthy margin: Katayama, Diniz,
Bruno Senna, Kvyat. Stroll, Pérez and Bottas, often named in this debate, are *not* separable from zero.

### How it is defined
- **"Their car" = the teammate's car.** The only fair like-for-like comparison in this data is two drivers in the same car
  in the same race weekend. No absolute "expected result for this car" exists, so the question is turned into "does he beat
  the other driver in the same machine, and by how much".
- **Qualifying** (`int_f1__teammate_quali_deltas`): lap time compared in the deepest session *both* drivers set a time in
  (Q3, else Q2, else Q1). Never best-vs-best across sessions, which would reward a driver whose teammate was knocked out earlier.
- **Race pace** (`int_f1__teammate_pace_deltas`): median green-flag lap time (the existing `fct_driver_race_pace` definition),
  both drivers needing 15+ clean laps. Race *results* are not used: they mix in reliability, strategy, safety cars and luck.
- Deltas are 100 x ln(time ratio), so a comparison and its mirror are exact opposites. Pairs more than 5% (qualifying) or 3%
  (pace) apart are dropped as unrepresentative (damage, red flags, traffic); this is a judgement call and is a constant at the
  top of each model.
- **Unit of evidence = a driver-teammate-season "stint".** Races inside a stint are not independent, so uncertainty is
  computed across stints, not across the ~20 races. A verdict needs 5+ stints against 3+ different teammates; otherwise
  `insufficient_data` (100 of 157 drivers).
- **Teammate-strength adjustment.** Beating a weak teammate proves little, so each stint is corrected by how that teammate
  did against *his other* teammates (leave-one-out). This is a first-order approximation of a full network rating. It changed the
  picture materially: Frentzen was #1 before adjustment (his teammates were weak or declining) and falls to indistinguishable;
  Sainz moves from slightly slower than his teammates to a significant overperformer (they were Verstappen, Norris, Leclerc).
  Raw and adjusted scores are both in the mart.

### Where the question is misleading
1. **The car dominates.** Across 160 constructor-seasons since 2010 the spread of team qualifying pace (standard deviation of
   the gap to pole) is about 1.4%. The spread of driver-vs-teammate differences is about 0.4% (mean absolute 0.31%, roughly
   0.3 seconds on a 90 s lap). Driver effects are real but small next to the car, and "overperform their car" is a statement
   about tenths of a second.
2. **It is relative, not absolute.** A driver is only measured against the specific people who sat in the other seat. Teammates
   are not random: a driver who spent his career next to weak teammates looks good, one paired with a star looks bad. The
   adjustment reduces this and cannot remove it, especially for drivers with few distinct teammates.
3. **Teams and drivers interact.** Set-up philosophy, team orders, and one driver being nursed to a development role (or
   favoured) all show up as "driver skill". The model cannot tell them apart.
4. **Zero-sum within a team.** Every positive score has a negative counterpart; the list says who beats his teammate, not who is
   good in absolute terms. Everyone in a top team can look "average".
5. **Eras are only linked by drivers who moved.** Scores are comparable within a connected group of teammates, and loosely
   across eras. Do not read "Schumacher #1 vs Verstappen #2" as a clean cross-era claim.
6. **Intervals are optimistic.** They treat stints as independent and ignore uncertainty in the teammates' own ratings.
   Barrichello's "significant" result is within rounding of not being so.

### Data limitations
- Qualifying times exist from 1994, lap times from 1996; earlier eras are not rated at all (so Fangio, Clark, Senna are absent
  or thin). Only 2018-2024 has data that is also plentiful per driver.
- 2024 rounds 23-24 arrived late in the raw feed; ratings for 2024 drivers (Colapinto, Bearman, Lawson, etc.) have too few
  stints and are `insufficient_data`.
- Mid-season team changes, shared drives, and wet or red-flagged weekends add noise that the trimming only partly removes.
- Qualifying uses the best lap in each session; a lap spoiled by traffic, not a driver deficit, counts against the driver.

---

## 2. "Are pit stops really getting faster, or is that a myth?"

**Short answer.** In this data, pit stops are **not** getting faster. Once the circuit mix is controlled for, pit *lane* time
is flat to slightly slower since 2011 (about +2.9% 2011 to 2024; +0.8% from 2014 on, within noise). The belief that crews are
faster is plausibly true for the *stationary* part of a stop, but this dataset cannot see it, so it neither confirms nor
refutes the myth. See `mart_pit_stop_trend_by_season` and `mart_pit_stop_trend_summary`.

| season | raw median (s) | circuit-adjusted index (2011 = 100) | change vs prior season |
|---|---|---|---|
| 2011 | 22.37 | 100.0 | |
| 2012 | 22.26 | 98.6 | -1.4% |
| 2013 | 22.87 | 99.0 | +0.4% |
| 2014 | 24.22 | 102.1 | +3.1% |
| 2015 | 24.25 | 102.2 | +0.2% |
| 2016-2019 | 23.5 to 23.8 | 101.1 to 101.6 | about 0 |
| 2020 | 24.17 | 101.7 | +0.1% (only 9 comparable circuits) |
| 2021 | 23.65 | 101.1 | -0.6% |
| 2022 | 23.69 | 103.3 | +2.2% |
| 2023 | 23.67 | 103.1 | -0.2% |
| 2024 | 23.29 | 102.9 | -0.2% |

Straight-line trend of the index, with standard error: 2011-2024 +0.26 +/- 0.06 points per year; 2011-2021 +0.21 +/- 0.10;
2014-2024 +0.12 +/- 0.07. There was a step slower in 2014 (+3.1%) and in 2022 (+2.2%), roughly when the technical regulations
changed; the data cannot attribute a cause. Since 2022 the index has drifted back down by about 0.4%.

### How it is defined
- Pit time is the recorded `milliseconds` (whole pit-lane transit, entry to exit). Stops over 60 s (red-flag stoppages) are
  excluded, same as `mart_constructor_season_pit_stops`.
- **The naive trend is wrong in both directions.** The raw season median rose from 22.4 s to 23.3 s, but each season races a
  different set of circuits and pit lanes differ in length by several seconds. So the index is **chain-linked**: for every circuit
  raced in two consecutive seasons take the change in its median pit lane time, take the median across circuits as that
  season's change, and chain from 2011. A circuit whose pit lane was rebuilt only distorts that circuit in that year, and the
  median shrugs it off. (A simpler "ratio to each circuit's all-time median" gives the same direction, +3.8% 2011 to 2024.)

### Where the question is misleading
1. **"Pit stop speed" is two different things.** The headline numbers people quote (2-3 seconds) are *stationary* time. This
   dataset has only pit-lane time, which is dominated by lane length and speed limit (typically 18 to 28 seconds). A crew could
   shave half a second of stationary time and the lane time would barely move.
2. **Pit lane time is also strategy.** Stops under a safety car, double-stacked stops, drive-through reductions and
   tyre-compound rules all change the recorded time without the crew changing anything.
3. **Fewer, different stops.** Stop counts per season fell from 1,113 in 2011 to about 536 in 2018, then rose again, and the
   mix of what each stop involves changed with the tyre rules. An average over stops mixes a changing population.
4. **Red flags are removed, not corrected.** Excluding stops above 60 s drops roughly 100 stops in 2021 and 2023 (red-flag
   stoppages); stops during long safety car periods are kept.

### Data limitations
- Pit stop data starts in 2011; there is no pre-2011 comparison (refuelling was banned in 2010, so the earlier era would not be
  comparable anyway).
- The raw `stop` number is unreliable (Monaco 2024 has stop numbers up to 70); nothing here uses it.
- A circuit-season needs 8 stops to be compared. 2020 has only 9 comparable circuits, so its step is less certain.
- A period of only a few seasons gives a very wide slope interval; the 2022-2024 window was left out of the summary on purpose
  (three points leave one degree of freedom, so its standard error would be meaningless).
