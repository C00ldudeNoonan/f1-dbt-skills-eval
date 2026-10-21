# Leadership questions: driver performance and pit stops

Models: `mart_driver_teammate_performance`, `mart_pit_stop_season_trend`, `mart_pit_stop_trend_summary`
(plus `int_teammate_*_gaps`, `int_driver_*_ratings`, `int_pit_stops_enriched`). Data: Ergast-style history through the
2024 season in the warehouse. Numbers below are from the current build and will move as data lands.

## 1. "Which drivers actually overperform their car? I want a list I can trust."

### The short answer
Only a handful of drivers can be shown, with statistical confidence, to beat the other driver in the same car, and the
question as phrased cannot be answered exactly. Of the 172 drivers with qualifying comparisons, 8 clear the bar
(`verdict = consistently_faster_than_teammates`):

| Driver | Seasons | Qualifying sessions | Different teammates | Avg qualifying gap to teammate (95% interval) | Ahead in qualifying |
|---|---|---|---|---|---|
| Max Verstappen | 2015-24 | 196 | 5 | -0.50% (-0.75, -0.24) | 78% |
| Michael Schumacher | 1991-2012 | 184 | 7 | -0.42% (-0.82, -0.01) | 66% |
| Fernando Alonso | 2001-24 | 371 | 13 | -0.37% (-0.49, -0.25) | 73% |
| Lando Norris | 2019-24 | 125 | 3 | -0.34% (-0.66, -0.02) | 70% |
| Nico Hulkenberg | 2010-24 | 222 | 10 | -0.30% (-0.54, -0.06) | 63% |
| Charles Leclerc | 2018-24 | 145 | 4 | -0.23% (-0.46, 0.00) | 67% |
| Sebastian Vettel | 2007-22 | 288 | 8 | -0.18% (-0.30, -0.05) | 64% |
| Lewis Hamilton | 2007-24 | 350 | 6 | -0.13% (-0.21, -0.04) | 62% |

Three drivers are shown to be consistently *slower* than their teammates (Coulthard, Diniz, Latifi); 55 are
inconclusive; 106 have too little data to say anything (including Piastri, Bearman, Colapinto and every recent rookie).
Read the table as "faster than the other driver in the same car, by roughly this margin", not as a ranking: intervals overlap, and
the first and last rows are not distinguishable from each other.

Hamilton's small raw gap (-0.13%) is a good example of why raw gaps mislead: his teammates were unusually strong
(Alonso, Rosberg, Button, Bottas, Russell). The jointly solved rating (below) puts him at -0.50%, in the middle of the
pack of the top eight.

### How "overperform the car" is defined here
The car is held constant by comparing each driver only with the *other driver of the same constructor in the same session*.

* **Qualifying gap**: best qualifying time vs the teammate's, as a percentage of the teammate's time (negative = faster).
  Same car, same track, same conditions. Gaps larger than 5% are dropped (crashes, red flags, mechanical trouble).
* **Race-pace gap**: the same using the median green-flag lap (requires 10+ green laps each; 1996 onwards). It must not
  contradict the qualifying result.
* **Uncertainty**: races in one season against one teammate share a car state and are not independent, so the unit of analysis
  is the (season, teammate) cluster and the 95% interval is cluster-robust with a Student-t multiplier. Few clusters mean
  wide intervals.
* **Joint rating** (`quali_rating_pct`): all teammate comparisons solved together (a least-squares rating over the whole
  graph of who partnered whom). Drivers who change team link the comparisons, so beating a weak teammate counts for less than
  beating a strong one. The rating is comparable only within one connected group; there is one group of 170 drivers (the
  other two drivers sit in a separate pair and are excluded by the evidence rule).
* **Verdict** needs: at least 40 qualifying sessions, at least 2 different teammates, at least 4 season-teammate
  clusters; the qualifying interval must exclude zero; the joint rating must be at least 0.10% away from zero; race pace must
  not point the other way.

### Where the question is misleading
* **"Overperform the car" cannot be measured directly.** There is no data on what a car "should" do. Beating the
  teammate says nothing about a driver who is extracting a great deal from a poor car if the teammate is equally good, and it
  rewards the driver who is simply the better of two in a car that is also great. Two excellent drivers cancel out
  (Hamilton/Rosberg), and a dominant car with a weak second driver inflates the first driver.
* **Cross-era comparisons are weak.** The joint rating links eras only through drivers who overlapped; a "-0.5%" in 1995
  and in 2023 are not the same quantity. Treat era-spanning ranking as indicative only.
* **A teammate is not a neutral benchmark.** Teams give priority to one driver (strategy, upgrades, team orders). Part of what
  looks like driver skill may be team treatment, and #2 drivers are often hired to be slower.
* **Multiple comparisons.** About 66 drivers were tested at 95%. Around three false positives are expected by chance, which is
  why the effect-size and race-pace conditions exist; Leclerc's interval touches zero and Schumacher's is only just clear.
* **Rookies and short careers are not "average"; they are unknown.** 106 drivers have insufficient data. Absence from the list
  is not evidence of being worse.

### Data limitations
* Qualifying times exist from 1994 (a single session until 2005, three-part knockout from 2006) and are missing when a driver set
  no time; race-pace needs lap data (1996 onwards). One 1995 qualifying time (`16:42.640`) is clearly a typo and is dropped by the 5% rule.
* Mid-season replacements and car upgrades are not tracked: "same constructor, same season" is treated as one car.
* No tyre, fuel, traffic, weather or penalty data, so a gap can reflect strategy or conditions, not pace.
* Gaps beyond 5% are dropped; this removes outliers but also some genuine large gaps, so the gaps of the slowest drivers against very fast teammates are understated.

## 2. "Are pit stops really getting faster, or is that a myth?"

### The short answer
**In this data they are not getting faster. If anything they got slower in 2014 and have been flat since.**
This does not necessarily contradict what teams say: the data records time in the pit lane, not the time the car is stationary.

| Season | Median pit lane time | Circuit-adjusted index (1.00 = typical at that circuit) | Stops per race |
|---|---|---|---|
| 2011 | 22.4 s | 0.966 | 58.6 |
| 2012 | 22.3 s | 0.945 | 47.3 |
| 2013 | 22.9 s | 0.978 | 49.7 |
| 2014 | 24.2 s | 1.017 | 41.6 |
| 2017 | 23.6 s | 0.995 | 33.8 |
| 2020 | 24.2 s | 1.001 | 31.3 |
| 2023 | 23.7 s | 1.008 | 36.7 |
| 2024 | 23.3 s | 1.001 | 32.1 |

* Across 2011-2024 the like-for-like trend is **+0.35% per year (slower)**; the level steps up by about 4% between 2013 and 2014 (7% from 2012) and
  then is flat: the 2014-2024 slope is -0.04% per year (t = -0.7, i.e. no detectable trend).
* On the same 15 circuits, the median stop in 2022-24 was 6.6% slower than in 2011-13, and 13 of those 15 circuits were slower.
  Across the 20 circuits with six or more seasons of data, 15 trend slower and 5 faster.
* The raw medians (22.4 s to 23.3 s) already show this; adjusting for the calendar does not change the conclusion, it just rules out
  "different circuits" as the explanation.

### How it is defined
* Stops over 60 s are excluded (red-flag stoppages, repairs, penalty serves): about 5% of all stops, concentrated in 2016 and 2020-2024.
* Each stop is divided by the median stop at the same circuit over all seasons (circuits with stops in at least 6 seasons), and the season
  median of that ratio is the "circuit-adjusted index". This removes the effect of a changing calendar and of pit lanes that differ by seconds.
* `mart_pit_stop_trend_summary` reports the regression slope, a naive t statistic (stops treated as independent, which overstates
  confidence, so only |t| > 3 is meaningful) and the circuit-by-circuit sign counts.

### Where the question is misleading
* **"Pit stop" is two things.** What teams have improved is the stationary tyre change (around 2 seconds). This feed records pit lane time:
  pit entry to pit exit, dominated by the lane length and the speed limit. A stop can be faster in the garage and no faster in the lane.
  This data cannot confirm or refute stationary-time improvement.
* **The 2014 step is a level change, not a trend, and its cause is not in the data.** Candidates (pit lane rules or speed limits, tyre and
  car changes, a change in how the timing feed records pit lane time) cannot be separated here, and I am not asserting any.
* **Fewer stops per race (58.6 in 2011 to about 32 now)** changes who stops and when, so stop quality is not comparable on volume alone.

### Data limitations
* Pit stop data only exists from 2011, so any pre-2011 claim is not testable here.
* Circuit coverage varies: 2020 had 17 races on 14 distinct circuits (several were visited twice), 2024 had 24.
* Per-team comparisons are possible (`int_pit_stops_enriched` has the constructor) but not published: team results are confounded by pit
  crew, strategy (more or fewer stops), and unlucky races.
