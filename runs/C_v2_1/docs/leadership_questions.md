# Two questions from leadership

Models: `mart_driver_vs_teammates`, `mart_driver_season_vs_teammate`,
`int_f1__teammate_qualifying_comparisons`, `mart_pit_lane_time_trend` and
`mart_race_pit_lane_times`. The figures below come from the 2026-10-21 build
and cover data to the end of 2024.

---

## 1. "Which drivers actually overperform their car?"

### Short answer

Eight drivers since 2006 are clearly faster than a typical teammate in the same
car. Each one holds up on two independent measures and on a large sample (at
least 120 races against at least three teammates):

| Driver | Years | Teammates | Races compared | Faster than a typical teammate by | Qualifying H2H | Race H2H (both finished) |
|---|---|---|---|---|---|---|
| Max Verstappen | 2015–2024 | 5 | 187 | 0.44% | 79% | 81% |
| Lewis Hamilton | 2007–2024 | 6 | 346 | 0.38% | 61% | 62% |
| Nico Rosberg | 2006–2016 | 5 | 198 | 0.27% | 59% | 52% |
| Fernando Alonso | 2006–2024 | 10 | 318 | 0.26% | 76% | 76% |
| George Russell | 2019–2024 | 4 | 122 | 0.26% | 74% | 66% |
| Lando Norris | 2019–2024 | 3 | 120 | 0.22% | 71% | 64% |
| Charles Leclerc | 2018–2024 | 4 | 145 | 0.20% | 65% | 63% |
| Sebastian Vettel | 2007–2022 | 8 | 281 | 0.20% | 62% | 63% |

A gap of 0.2–0.4% of lap time is about 0.2–0.35 seconds over a 90-second lap.

Nine drivers are clearly *slower* than a typical teammate (for example Stroll,
Massa and Kvyat). About 37 more have enough data and are statistically level
with a typical teammate. That group includes several race winners, such as
Räikkönen, Button, Bottas and Pérez. Another 45 drivers (rookies, short
careers, a single teammate, for example Piastri) don't have enough evidence for
any verdict.

### How it's measured

- **The car is never observed directly, so the benchmark is the teammate,** who
  drives the same car in the same weekend. That's the only clean control in
  the data.
- **Qualifying pace is the primary measure.** It's a single-lap comparison in
  the same session, so strategy, team orders, traffic and reliability don't
  affect it. Each race compares the two cars' times in the last session both
  drivers set a time in.
- **Adjusted for teammate strength.** Beating a weak teammate is worth less
  than beating a strong one. Each comparison adds the teammate's own median
  advantage over their *other* partners. The result estimates the driver's
  advantage over a typical teammate. Sainz shows why this matters: he gets one
  of the best adjusted scores because his teammates included Verstappen,
  Leclerc and Norris, but he still lost 55% of his head-to-heads. So he's
  classified "not distinguishable", not as an overperformer.
- **A verdict needs two signals to agree.** The adjusted advantage must exceed
  0.1%, *and* the qualifying head-to-head must be better than 50/50 at 95%
  confidence (Wilson interval). Large samples and several teammates are
  required too (trust tiers).
- **The race head-to-head is shown for context but doesn't decide the
  verdict.** It counts only races where both cars finished, so breakdowns
  don't count against a driver. It still reflects strategy and team orders.

### Assumptions and limitations

- **2006 onwards only.** Earlier qualifying used single-lap or race-fuel formats,
  or the data is sparse. Before 2010, Q3 was run on race fuel, so for those
  seasons the comparison uses Q2. Legends from before 2006 can't be assessed
  this way.
- **Qualifying is not the whole job.** Race craft, tyre management, consistency
  and wet-weather skill aren't captured, apart from the secondary race
  head-to-head.
- **Gaps over 2% are treated as incidents** (crashes, mechanical problems,
  rain arriving mid-session) and left out of the pace figure.
- **Teammates aren't always equal.** Number-one status, upgrade parts arriving
  for one car first, and different setup directions all bias the comparison.
  The data can't see them.
- **The strength adjustment is first-order.** It uses each teammate's record
  across their whole career, so ageing, team changes and era effects blur it.
  It's an estimate, not a precise rating.
- **Selection bias.** The best drivers tend to get the best cars and the best
  teammates. Long careers in strong teams produce many comparisons against
  strong opposition, while drivers dropped early never build the sample needed
  for a verdict.

### Where the question misleads

"Overperform their car" assumes we know what the car was worth on its own. We
don't, and no dataset does. What we can measure is how a driver compares with
the other person in the same car. A driver who looks "average" by this measure
may simply have had excellent teammates. That's why the list is adjusted for
teammate strength, and why most drivers come out as statistically level. Treat
the eight names as robust. Don't read the small differences between them as a
ranking: their adjusted gaps overlap.

---

## 2. "Are pit stops really getting faster, or is that a myth?"

### Short answer

**The data can't tell us whether the *stops* got faster. It does show that the
total time cars lose in the pit lane hasn't fallen since 2013.**

- **What we can measure is the whole pit-lane visit,** from the pit-entry to
  the pit-exit timing line, typically about 23 seconds. The crew's stationary
  time, the 2–3 seconds the "pit stops are getting faster" claim is about, is
  not in this data.
- **The change in pit-lane time is a rule change, not crews.** At most circuits
  pit-lane time jumped by about 2.5 seconds between the 2013 German and
  Hungarian Grands Prix. That's consistent with the lower pit-lane speed limit
  introduced mid-2013.
- **Since then, circuit for circuit, there's no trend.** Comparing each race with
  the same circuit's own norm, the trend is −0.02 seconds per season (about
  0.2 seconds across 11 seasons). Season explains under 1% of the variation
  (R² = 0.004). The quickest 10% of stops show the same thing (−0.007 s per
  season).

| Season | Raw median (s) | vs same circuit's norm (s) |
|---|---|---|
| 2014 | 24.2 | +0.24 |
| 2016 | 23.8 | −0.01 |
| 2018 | 23.7 | −0.16 |
| 2021 | 23.7 | −0.28 |
| 2022 | 23.7 | +0.15 |
| 2024 | 23.3 | −0.07 |

### Why the raw numbers mislead

- **The raw median says stops got slower,** from 22.4 s in 2011 to about 23.5 s
  now. Almost all of that is the 2013 speed-limit change.
- **The rest of the movement is the calendar.** Pit lanes differ hugely between
  circuits (Singapore's is around 30 s, Barcelona's around 22 s), so adding or
  dropping circuits moves the raw average without anything getting faster or
  slower.
- **So compare each circuit with itself, within the same rules regime.** The
  trend model does exactly that.

### Assumptions and limitations

- **Pit stop data starts in 2011,** after refuelling was banned, so the biggest
  historical change in stop times isn't covered.
- **Some stops can't be told apart.** Drive-through penalties, slow stops for
  repairs, and stops under safety car or red flag all appear as ordinary
  stops. Stops over 60 s are excluded as red-flag stoppages. The 10th
  percentile is reported to focus on clean stops.
- **The regime boundary is an assumption.** It's set at the 2013 Hungarian GP
  from the data and is configurable (`pit_regime_start_date`). A warn-level
  test (`assert_pit_regime_break_present`) checks that the break is still
  there. Other pit-lane changes, such as circuit layouts or new pit buildings,
  aren't modelled. The circuit baseline absorbs persistent changes only
  partly.
- **2020 is thin.** Only 10 comparable circuits, because of the COVID calendar.

### Where the question misleads

"Pit stops" means two different things. Crew stationary times have, by public
accounts, improved steadily, with records under 2 seconds. Pit-lane time is
what costs a driver race time, and it's set mostly by the pit lane and the
speed limit. To test the stationary-time claim we would need a different data
source with stationary times, for example the teams' or broadcaster's
"fastest pit stop" figures.
