# Two leadership questions: car vs driver, and pit stop speed

Built on: `mart_driver_overperformance`, `mart_driver_teammate_pairs`, `int_teammate_pace_deltas`, `int_driver_teammate_ratings`
(Q1) and `mart_pit_stop_season_trend`, `mart_pit_stop_circuit_season`, `int_pit_stops_routine` (Q2). Data covers 1950-2024; the
analyses use the seasons where the needed data exists (qualifying from 1994, green-flag lap pace from 1996, pit stops 2011-2024).

---

## Q1. "Which drivers actually overperform their car? I want a list I can trust."

### The short answer
Of 70 drivers with enough evidence, **17 are clearly faster than the teammates they were given**, 15 are clearly slower, and 38
cannot be separated from their teammates. Ordered by teammate-adjusted rating (below), the clear overperformers are:

Michael Schumacher, Max Verstappen, George Russell, Lewis Hamilton, Nico Rosberg, Heinz-Harald Frentzen, Sebastian Vettel,
Fernando Alonso, Lando Norris, Charles Leclerc, Mark Webber, Mika Häkkinen, Nico Hülkenberg, Adrian Sutil, Pierre Gasly,
Damon Hill, Mika Salo.

Clearly slower than their teammates (read this as "was beaten in the same car", not "is bad"): Felipe Massa, Stoffel Vandoorne,
Sergio Pérez, David Coulthard, Jean-Éric Vergne, Martin Brundle, Vitaly Petrov, Esteban Gutiérrez, Alexander Wurz,
Lance Stroll, Marcus Ericsson, Christian Klien, Pedro Diniz, Nicholas Latifi, Narain Karthikeyan.

The full table, with the numbers behind every name, is `mart_driver_overperformance`. Read `verdict`, `edge_pct`, `se_pct` and
`adjusted_rating_pct`.

### What "overperform" means here (my definition)
The data has no car performance measurement, so the only fair control for the car is **the other driver in the same car on
the same weekend**. A driver overperforms if they are consistently faster than their teammates.

* **Metric:** percent difference in lap time (so tracks and eras are comparable), driver minus teammate.
  * *Qualifying* (primary): the latest session **both** drivers reached (Q3, else Q2, else Q1). A driver knocked out in Q1 is never
    compared against a teammate's Q3 lap on a faster track.
  * *Race pace* (corroboration, 1996+): median green-flag lap (no lap 1, no pit laps, no slow laps) with 10+ such laps each.
  * Pairs more than 10% apart are dropped (crashes, red flags, mechanical failures, the 16:42 Q1 time in the raw data): they say
    nothing about skill.
* **Verdict `overperforms`** needs: mean advantage over teammates more than 2 standard errors from zero **and** race pace not
  contradicting it, with at least 30 qualifying comparisons, 2 different teammates and 3 seasons. Everything else is
  `indistinguishable` or `insufficient_data` (103 drivers). The list is deliberately conservative.
* **Ranking** uses a shrunk estimate (empirical Bayes, pulled towards zero in proportion to its noise) so a short career cannot top
  the table by luck.

### The key trap, and how it is handled: teammate quality
"Beat his teammate" depends on who the teammate was. Hamilton's raw edge over his teammates is only +0.12% because he spent his
career next to Alonso, Button, Rosberg, Bottas and Russell; Frentzen's is +0.59% against mostly weak teammates. So there are two
columns, and they answer different questions:

* `edge_pct`, `verdict`: what the driver did against the people actually in their garage.
* `adjusted_rating_pct` (`int_driver_teammate_ratings`): chains every teammate comparison across the grid (drivers change teams, so
  the grid is connected) and solves for one rating per driver, so beating a champion counts for more than beating a backmarker.
  **Use this to compare drivers across teams and eras.** It moves Hamilton from 23rd to 4th and Frentzen from 1st to 6th.
  `teammate_strength_pct` shows how tough each driver's garages were.

### Limitations, honestly
* **Teammate-relative, not absolute.** A driver always paired with a superstar can look bad (Massa: `underperforms` against Alonso,
  Räikkönen and Hamilton but adjusted rating +0.18) and a driver with a weak team-mate can look great. The adjustment helps, it does
  not make it perfect; ratings have uncertainty of several hundredths of a percent.
* **Car-specific fits.** A car can suit one driving style. Two teammates is a comparison of two styles in one car, not a pure skill
  contest.
* **Qualifying pace is not race craft.** Wet-weather skill, tyre management, starts, overtaking, consistency, and team orders are
  invisible. Race pace is a corroborating check, not a full race-skill measure; it is affected by strategy and traffic.
* **Team orders and number-one drivers.** If a team favours one driver (parts, strategy), the other looks worse; the data has no flag
  for this.
* **Data coverage.** Qualifying is only reliable from 1994 (earlier drivers are excluded entirely), some old seasons have sparse
  qualifying (e.g. 1998, 2002), and the raw feed has quirks (see README). Careers that began before 1994 are measured only on
  their post-1994 part.
* **Short stints.** Drivers with fewer than 30 comparisons, 2 teammates or 3 seasons are `insufficient_data`; the recent
  rookies (e.g. Piastri, Lawson, Bearman) are not judged yet.

### The question itself is slightly misleading
"Overperform their car" assumes the car has a fixed, measurable performance the driver can be compared to. We can only measure a
driver *relative to the other driver in the car*, and drivers influence car development, so car and driver are not cleanly
separable. "Beats his teammates, after accounting for how strong those teammates were" is the defensible claim.

---

## Q2. "Are pit stops really getting faster, or is that a myth?"

### The short answer
**In this data, no.** Like-for-like, pit stops have not gotten faster; they are about **1 second slower** than at the start of the
data (2011-13), and 2024 is roughly back to 2019-2023 levels, not better.

| Era | Stops | Median pit lane time | Fastest 10% | Slowest quartile starts at |
|---|---|---|---|---|
| 2011-13 | 3,003 | 22.5 s | 20.1 s | 24.6 s |
| 2014-18 | 3,652 | 23.9 s | 20.4 s | 26.0 s |
| 2019-24 | 4,199 | 23.7 s | 20.7 s | 26.7 s |

On the 15 circuits that appear in both 2011-13 and 2022-24, the median pit stop is **1.1 s slower** later (12 circuits slower,
3 faster). The step change is between 2013 and 2014 (+5.6% on the circuit-adjusted index), not a gradual trend, and nothing since
brings it back down. Year-by-year values are in `mart_pit_stop_season_trend` (use `circuit_adjusted_index`, not
`raw_median_seconds`).

### What I measured and why the raw numbers mislead
* The feed reports **pit lane time** (entry to exit), not the 2-3 second **stationary** time teams quote when they say stops are
  getting faster. Crews can be much quicker while this number does not move, because most of it is driving down the pit lane.
* Pit lane length and speed limit differ by several seconds between circuits (about 18 s to 30 s medians), and the calendar changes
  every year (14 circuits in 2020, 24 in 2024). The raw yearly median mostly measures which circuits were visited. I therefore
  compare each circuit with itself (`relative_to_circuit`) and index seasons on circuits seen in at least 3 seasons.
* Stops over 60 seconds are excluded (red flags and repairs, consistent with the rest of the project); 517 stops.
* The one big improvement (Albert Park, -5.1 s) is almost certainly a changed pit lane or layout (the circuit was reprofiled in 2022), not crews getting faster; I have not verified the cause.

### Limitations
* Only 2011-2024 exist; the "old days" (refuelling era, before 2010) cannot be compared.
* Rule changes could explain the 2014 step (e.g. pit lane speed limit and procedure changes, new power units), but the data cannot
  show causes, only that the step happened.
* There is no stationary time, no flag for penalties (a drive-through or stop-go counts as a stop if the feed includes it), no tyre
  compound, and no crew or team assignment for individual stops beyond the driver's constructor.
* Fewer stops per race now (about 1,100 in 2011 vs 540-800 in recent years), so recent yearly medians rest on fewer observations.
* **The fastest teams can still be quick:** the fastest-10% time has barely moved, so elite stops are roughly where they were.

### The question itself is slightly misleading
"Faster" can mean the crew's stationary time, the pit lane time, or the cost of a stop in lost race time. This data supports only
the second. If leadership wants to know whether crews are faster, we need stationary-time data from the timing provider.
