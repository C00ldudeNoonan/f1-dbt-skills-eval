# Leadership questions: answers and method

Models: `mart_driver_vs_car`, `mart_pit_stop_trend` (plus the intermediates
they're built on). Figures are from the data as of the 2024 season.

---

## 1. "Which drivers actually overperform their car?"

### Short answer

Fourteen drivers since 1994 are faster than the average F1 driver *in the same
car* with 95% confidence on **both** one-lap and race pace:

| # | Driver | Seasons | Qualifying rating | Race-pace rating |
|---|---|---|---|---|
| 1 | Max Verstappen | 2015–2024 | −0.64% | −0.77% |
| 2 | Lando Norris | 2019–2024 | −0.63% | −0.50% |
| 3 | Charles Leclerc | 2018–2024 | −0.48% | −0.49% |
| 4 | Carlos Sainz | 2015–2024 | −0.44% | −0.46% |
| 5 | Lewis Hamilton | 2007–2024 | −0.47% | −0.40% |
| 6 | George Russell | 2019–2024 | −0.50% | −0.35% |
| 7 | Nico Rosberg | 2006–2016 | −0.46% | −0.39% |
| 8 | Michael Schumacher | 1994–2012 | −0.46% | −0.32% |
| 9 | Fernando Alonso | 2001–2024 | −0.40% | −0.36% |
| 10 | Sebastian Vettel | 2007–2022 | −0.30% | −0.34% |
| 11 | Daniel Ricciardo | 2011–2024 | −0.34% | −0.30% |
| 12 | Nico Hülkenberg | 2010–2024 | −0.34% | −0.25% |
| 13 | Pierre Gasly | 2017–2024 | −0.38% | −0.20% |
| 14 | Jenson Button | 2000–2017 | −0.19% | −0.13% |

A rating of −0.5% means about 0.4 s a lap faster, on a 80 s lap, than an
average F1 driver would be in that car. `select * from mart_driver_vs_car
where is_trusted_overperformer order by trusted_rank`.

### What "overperform the car" means here

You can't observe "the car" separately from whoever drives it. The only clean
control is the **teammate**: same car, same weekend, same conditions. So
overperformance = **extracting more pace from the same car than the average F1
driver would**, measured two independent ways:

- **Qualifying:** gap to the teammate in the last session *both* set a time
  in (Q3, else Q2, else Q1; the single session before 2006), so both ran on the
  same track at the same time. 1994 onwards.
- **Race pace:** gap in median green-flag lap time (no lap 1, pit laps or slow
  laps, at least 10 laps each). 1996 onwards.

Gaps are `100 × ln(driver / teammate)`, % of lap time. Same-car gaps above 3%
(crash, failure, mixed conditions) are dropped as non-representative.

### Why raw teammate gaps aren't enough

Beating a weak teammate is easy. Raw gaps put Frentzen and Panis near the top
and Hamilton (teammates Alonso, Rosberg, Bottas, Russell) mid-table, while
Sainz looks merely average (+0.02% raw) after partnering Verstappen, Norris and
Leclerc. `int_driver_network_ratings` (a Python model) fixes this with a
weighted least-squares fit over the whole teammate network:
`rating(driver) − rating(teammate) ≈ observed gap` for every pair, weighted
by the number of comparisons, centred so the average driver is 0. Beating a
fast teammate therefore counts for more. Its standard errors propagate
teammates' uncertainty too.

### Why the list can be trusted, and what "trusted" excludes

A driver is listed only if, on **both** signals, they have enough evidence
(≥ 50 qualifying and ≥ 30 race comparisons), are in the main teammate
network, and the **whole 95% interval** is faster than average. Of 60 drivers
with enough data, 14 qualify. Being off the list is not a verdict: many drivers
are probably good but the data can't separate them from average. Two examples:

- **Bottas** is clearly fast over one lap (−0.28%) but average in race pace (+0.03%).
- **Räikkönen** and **Barrichello** are just short on race pace.

Seven drivers are reliably *slower* than average in the same car (both
intervals above zero).

### Assumptions and limitations

- **Driver–car interaction is ignored.** Some drivers suit some cars, and
  teams sometimes favour one car (strategy, upgrades, team orders). A career
  rating averages over this.
- **Teammates aren't independent of the result.** Strong drivers get strong
  teammates at top teams, and rookies often debut against established drivers.
  Ratings are relative to the comparison-weighted average driver in the
  network, so era mix matters. Cross-era comparisons rest on chains of
  teammates and should be read loosely.
- **Careers are averaged.** Rookie seasons and late-career decline are mixed
  in, and a peak-years view would rank differently.
- **Pace, not racecraft.** Overtaking, tyre management, starts, consistency,
  wet-weather skill and avoiding errors are only partly captured (mistakes
  over 3% are excluded entirely). Results and points aren't used at all,
  because they depend heavily on reliability and strategy.
- **Coverage:** timing data starts in 1994 for qualifying and 1996 for laps.
  Earlier greats (Senna, Prost, Clark and others) can't be rated.
- **Qualifying fuel:** 2003–2009 qualifying was run with race fuel, which
  adds noise to that era's qualifying gaps.

### Why the question itself can mislead

"Overperform their car" invites ranking drivers by results relative to car
quality. Results are dominated by the car, by reliability and by team
decisions, so such lists mostly measure noise or luck. Same-car pace is the
part of driver quality the data can actually isolate. It is relative to
teammates, so the answer to "does X overperform?" depends on who X was
measured against, which the network adjustment only partly solves.

---

## 2. "Are pit stops really getting faster, or is that a myth?"

### Short answer

**In this data, they are not getting faster.** Adjusted for circuit, pit-stop
time has been flat for a decade. Since 2016 every season is within ±0.25 s of
normal, and every 95% interval includes zero. The trend for 2016–2024 is
+0.03 s/year (95% CI −0.03 to +0.10). Over 2011–2024 it is actually slightly
*slower*, +0.05 s/year (CI +0.02 to +0.09): 2011–12 were 1.0–1.5 s quicker
than normal and 2014–15 about 0.3–0.5 s slower.

| Season | Raw median (s) | Circuit-adjusted vs normal (s) | 95% CI |
|---|---|---|---|
| 2011 | 22.37 | −1.01 | −1.59 to −0.44 |
| 2012 | 22.26 | −1.52 | −2.01 to −1.03 |
| 2013 | 22.87 | −0.02 | −0.65 to 0.60 |
| 2014 | 24.22 | +0.47 | 0.31 to 0.63 |
| 2015 | 24.25 | +0.26 | 0.06 to 0.46 |
| 2016–2024 | 23.3–24.2 | −0.23 to +0.24 | all include 0 |

`select * from mart_pit_stop_trend order by season`.

### Why the question misleads

- **"Pit stop" means two different things.** The famous sub-2-second figures
  are *stationary* time: the car stopped while the tyres are changed. Our feed only
  records **pit-lane time**, from pit entry to pit exit, about 20–30 s. Stationary time
  is only ~10% of that, and the rest depends on pit-lane length and the speed
  limit. So the data **cannot confirm or refute** claims about tyre-change
  speed. What it shows is that the total time a stop costs a driver hasn't
  fallen. Any stationary-time gains have been small, or offset by other
  changes (pit-lane rules, release procedures, speed limits).
- **Raw yearly medians mostly track the calendar.** Pit lanes differ by
  several seconds between circuits. That's why each stop is compared with the
  same circuit's own long-run median, and circuits are weighted equally per
  season.
- **The fastest single stop is a poor measure.** It is a one-off extreme
  (penalties, data glitches and quirky pit lanes all appear in the tails),
  not a trend.

### Assumptions and limitations

- Coverage is 2011–2024 only, because the feed has no earlier pit data.
- Stops over 60 s (red-flag stoppages) are excluded. Medians absorb most
  drive-throughs and penalty stops.
- Circuit baselines assume a circuit's pit lane didn't change over the
  period; circuits need at least 3 seasons of data to count. Layout or
  speed-limit changes at a venue show up as noise for that venue.
- 2020 had an unusual calendar (12 comparable circuits).
- Several seasons have implausibly short outlier stops in the tails (for
  example 2017 and 2021, 4–5 s below circuit norm), probably data errors. Medians
  are unaffected.
