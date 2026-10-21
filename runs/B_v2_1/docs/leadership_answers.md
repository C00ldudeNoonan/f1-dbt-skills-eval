# Two questions from leadership

Data: Ergast F1 feed in `ANALYTICS_DEV`, as built on 2026-10-21. Models:
`mart_driver_car_overperformance`, `mart_driver_vs_teammate_seasons`,
`mart_pit_stop_trends` (plus intermediates). Every number below can be
reproduced from them.

---

## 1. "Which drivers actually overperform their car?"

### Short answer

Since 2006, seven drivers are measurably faster than their teammates in the
same car, after adjusting for how strong those teammates were:

| # | Driver | Adjusted gap vs average teammate | 95% interval | Teammates | Qualifying H2H |
|---|---|---|---|---|---|
| 1 | Max Verstappen | −0.43% | −0.65 to −0.20 | 5 | 79% |
| 2 | Lewis Hamilton | −0.40% | −0.46 to −0.34 | 6 | 63% |
| 3 | Fernando Alonso | −0.30% | −0.42 to −0.18 | 10 | 76% |
| 4 | Nico Rosberg | −0.27% | −0.48 to −0.06 | 5 | 61% |
| 5 | George Russell | −0.27% | −0.44 to −0.09 | 4 | 73% |
| 6 | Carlos Sainz | −0.24% | −0.36 to −0.12 | 6 | 46% |
| 7 | Charles Leclerc | −0.23% | −0.45 to −0.01 | 4 | 64% |

Read −0.40% as "about 0.35 s per lap faster than an average teammate in the
same car" (on a 90 s lap). Next come Norris (−0.23%), Trulli (−0.23%) and
Vettel (−0.21%), whose intervals still touch zero. They may well be faster
than their teammates, but the data can't separate them from average yet. Of
the 99 drivers with any comparisons since 2006, 42 have enough evidence to
rank. One (Latifi, +0.44%) is measurably *slower* than his teammates.

### What the question really asks, and why it's tricky

- **A car's true pace can't be observed.** Every "car-adjusted" measure needs
  a proxy. The only one that holds the car fixed is the **teammate**: same car,
  same weekend, same conditions. So the honest version of the question is
  "who beats their teammates, and by how much, given who those teammates were?"
- **Beating a teammate isn't the same as beating the car.** A driver paired
  with a great teammate looks average. Sainz loses the raw head-to-head (46%),
  but his teammates were Verstappen, Norris, Leclerc and Hamilton. Adjusted
  for that, he's clearly above average. Raw head-to-heads and points totals
  reward drivers who got weak teammates.
- **"Trust" needs an uncertainty band.** Rankings of close drivers flip with
  small data changes. The list above includes only drivers whose 95% interval
  excludes zero.

### Method

1. **Same-session qualifying gaps** (`int_teammate_qualifying_gaps`). For
   each race, compare the two team cars in the latest qualifying session
   both took part in (Q3, else Q2, else Q1). Comparing best times across
   sessions would fold track evolution into the gap. Gaps beyond ±3% (2.4% of
   comparisons) are treated as incidents (crashes, failures, rain) rather
   than pace, and excluded.
2. **Per teammate-season median** (`mart_driver_vs_teammate_seasons`). The
   median is robust to the odd bad session.
3. **Teammate-strength adjustment.** Each teammate-season gap is shifted by
   that teammate's own average gap against *their other* teammates. Losing
   by 0.1% to Hamilton is better than beating a rookie by 0.1%.
4. **Confidence.** A 95% interval across teammate-seasons, treating each one
   as a sample. That's deliberately conservative: races within a season
   aren't independent.
5. **Ranking threshold.** ≥ 50 comparisons, ≥ 3 different teammates and ≥ 4
   teammate-seasons. One teammate can't separate a driver from that teammate.

Why qualifying and not race results: qualifying is the cleanest pace signal
we have. Race results mix in reliability, strategy, team orders and
first-lap luck. Race head-to-heads (both cars classified) are in the mart as
context. They broadly agree: Verstappen 81%, Alonso 76%, Hamilton 62%.

### Limitations

- **Qualifying pace isn't everything.** Racecraft, tyre management,
  consistency and wet-weather skill aren't measured. A driver who is
  ordinary over one lap but excellent in races (or the reverse) is mis-rated.
- **Coverage starts in 2006.** Before then the dataset has qualifying times
  for only some races (often 5–15 comparisons per teammate-season). That's
  too thin to rank, so Senna, Prost and Schumacher's peak can't be assessed
  this way. The cut-off is a project variable (`overperformance_min_season`).
- **Equal machinery is assumed.** Team-mates don't always have identical
  cars (number-one status, upgrade timing, chassis swaps). The data can't see this.
- **The adjustment is one step.** It measures teammates against their other
  teammates, but not those teammates' teammates. A full network fit would
  be more precise, but an iterative solve inside every build proved too slow
  (minutes per run), so it was left out. Including the thinner pre-2006 data
  keeps today's drivers in the same order (Verstappen, Hamilton, Rosberg,
  Alonso near the top). It adds pre-2006 drivers (Schumacher first) on much
  weaker evidence, for example Alesi at #2 on 60 comparisons.
- **These are career averages since 2006.** They say nothing about current
  form or a driver's peak.

---

## 2. "Are pit stops really getting faster, or is that a myth?"

### Short answer

**Not in the time that matters for the race.** The total time a car spends in
the pit lane, compared with each circuit's own norm, was **lowest in
2011–2013** (0.4–1.2 s quicker than usual). It **jumped by about 0.75 s in
2014** (from −0.37 s to +0.38 s against the circuit norm) and has been
**essentially flat since** (−0.02 s per season from 2014 to 2024).
The fastest crew each season shows the same flat trend after 2014 (about 0.00 s
per season).

| Season | Median vs circuit norm (s) | Best crew's median vs norm (s) |
|---|---|---|
| 2011 | −0.67 | −1.65 |
| 2012 | −1.17 | −2.20 |
| 2013 | −0.37 | −0.99 |
| 2014 | +0.38 | −0.16 |
| 2016 | +0.08 | −0.53 |
| 2019 | +0.05 | −0.35 |
| 2021 | −0.31 | −0.69 |
| 2023 | +0.19 | −0.26 |
| 2024 | +0.08 | −0.31 |

(Full series in `mart_pit_stop_trends`. A fixed set of venues with pit data
in at least 10 seasons gives the same pattern.)

### Why the question is misleading

- **"Pit stop" means two different things.** The headline numbers (a 1.8 s
  world-record stop) are *stationary* time: car stopped to car released.
  This data records *pit-lane* time: entry to exit, about 20–25 s, almost all
  of it driving at the speed limit. The stationary part is a small slice of
  that, so a 0.5 s improvement in crew work barely moves the total. Ours is
  the number that decides races, but it can't confirm or refute the
  stationary-time claim.
- **Raw averages mislead.** Pit lanes differ in length by several seconds.
  The raw median jumps around with the calendar: 2020 was 24.2 s mostly
  because of unusual venues. Every comparison here is relative to the same
  circuit's norm.
- **The 2014 step is real, but its cause isn't in the data.** It coincides
  with the 2014 rule changes. Pit-lane speed limits, pit-lane layouts and car
  changes can all move this number, and this data can't separate them.

### Method

- Pit stop data runs from 2011 to 2024. Only service stops count (≤ 60 s).
  Longer ones are red-flag stoppages, repairs or penalties served in the pit lane.
- Each stop is compared with its circuit's all-season median.
  `median_vs_circuit_s` is the season median of that difference.
  `best_crew_median_vs_circuit_s` is the fastest team's median (teams with at
  least 20 stops).

### Limitations

- No stationary times, as above.
- Pit-lane layouts sometimes change at the same circuit (a new pit exit, a
  different speed limit), which this method attributes to the season.
- Stops per car vary with tyre rules and strategy (1.7–2.9 per race). That
  changes which stops are made, not how fast each one is.

---

## Tests that back this up

- **Qualifying comparisons:** they use the latest common session (unit
  test), and every pair is mirror-consistent (A ahead of B ⇔ B behind A).
- **Driver ranking:** each interval contains its estimate, ranks are unique
  among rankable drivers, and verdicts take only the documented values.
- **Pit stop series:** it accounts for every service stop exactly once, with
  one row per season.
