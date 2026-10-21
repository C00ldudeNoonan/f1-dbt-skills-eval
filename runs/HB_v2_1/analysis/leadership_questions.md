# Two questions from leadership

Models: `mart_driver_overperformance`, `mart_pit_stop_trend_by_season`, `mart_pit_stop_speed_trend`.
Data as of the 2026-10-21 build. Tests for each model are in `models/marts/_marts__performance_questions.yml`.

## 1. Which drivers actually overperform their car?

**Short answer.** Verstappen and Alonso lead the list, and their advantage over the teammate is large
and well supported. Further down, the evidence gets thin quickly. Read the list as a shortlist to
investigate, not as a verdict on individuals.

**Definition.** Both drivers in a pair drove the same car, so the car cancels out. For each race where
two teammates were both classified, the gap is the teammate's finishing position minus the driver's.
Positive means the driver finished ahead. A driver's score is the mean gap over all their races from
1981 onward. The list ranks drivers by the **lower 95% bound** of that mean, and only includes drivers
with at least 30 race pairs over at least 3 seasons. Ranking by the lower bound means a driver scores
high only when the evidence is strong, not when a small sample happens to look good.

**Top of the list** (`rank_by_lower_95`, race pairs, mean gap, 95% range):

| Rank | Driver | Race pairs | Seasons | Mean gap | 95% range |
|---|---|---|---|---|---|
| 1 | Max Verstappen | 149 | 10 | +2.53 | +1.86 to +3.20 |
| 2 | Fernando Alonso | 276 | 21 | +2.23 | +1.74 to +2.72 |
| 3 | Nelson Piquet | 59 | 11 | +1.86 | +0.85 to +2.88 |
| 4 | Michael Schumacher | 182 | 19 | +1.24 | +0.66 to +1.83 |
| 5 | Ayrton Senna | 72 | 10 | +1.51 | +0.46 to +2.56 |
| 6 | Charles Leclerc | 113 | 7 | +1.16 | +0.37 to +1.94 |
| 7 | Lewis Hamilton | 292 | 18 | +0.83 | +0.35 to +1.31 |

73 drivers meet the threshold. Hamilton's mean is lower than Verstappen's, but his sample is far larger
(292 pairs), so his interval (0.96 wide) is about as narrow as Alonso's (0.98) and much narrower than
Verstappen's (1.34). That is what the lower-bound ranking is meant to reward.

**Assumptions.**
- A teammate is a fair baseline for the car. It is not a neutral one: a driver whose teammates were
  weak looks better than they are.
- Only races where both drivers are classified count. A teammate's retirement drops the pair, so
  reliability does not penalise either driver. The cost is that the list ignores reliability entirely.
- The 95% range assumes races are independent. They are not: a driver's gaps are correlated within a
  season, because the car changes through the year. Real uncertainty is wider than shown. This is the
  biggest limitation of the list.
- Position gaps ignore grid, pace and strategy. A driver who starts ahead gains less, and the list does
  not correct for that. Qualifying gaps are in the model (`mean_quali_gap`) and agree in direction for
  most top drivers, but they are not used in the ranking.
- Seasons before 1981 are excluded. Shared cars and repeated driver pairs make a teammate comparison
  unreliable there.

**Where the question misleads.** "Overperform their car" implies a measure of the car on its own. The
results contain no such measure. A teammate comparison is the best available proxy, and it always
measures the driver against whoever shared the car.

## 2. Are pit stops really getting faster, or is that a myth?

**Short answer.** Pit stops are not getting faster. After adjusting for circuit, the typical stop in
2022–2024 is about one second slower than in 2011–2013. The trend is flat to slightly rising, and the
season explains almost none of the variation between stops.

**Definition.** Stop duration is the `MILLISECONDS` column for each stop, from 2011 onward. Stops over
60 seconds are excluded as red-flag stoppages. "Circuit-adjusted" subtracts, from each stop, the median
stop at its own circuit over all seasons, and uses only circuits with at least 8 seasons of stops (19
circuits). That removes the effect of which circuits held races in a given year.

| Season | Median (s) | Circuit-adjusted median (s) | Circuit-adjusted mean (s) |
|---|---|---|---|
| 2011 | 22.37 | −0.73 | −0.15 |
| 2013 | 22.87 | −0.43 | −0.59 |
| 2015 | 24.25 | +0.38 | +1.14 |
| 2019 | 23.52 | −0.02 | +0.96 |
| 2021 | 23.65 | −0.29 | +0.53 |
| 2023 | 23.67 | +0.18 | +1.00 |
| 2024 | 23.29 | +0.03 | +0.72 |

- Averaged over 2011–2013, the circuit-adjusted median is −0.87 s. Averaged over 2022–2024 it is +0.16 s.
- Regressing each stop's adjusted time on season gives a slope of +90 ms per season, with R² of 0.01.
  The median series slopes at +60 ms per season. Neither is an improvement.
- The adjusted *mean* is higher in recent years than in 2011–2013. The slow tail has grown: more of
  the stops are long, even though the typical stop is no faster.
- The fast end has not improved either. The 10th percentile sits near 20 seconds in most seasons.

**Assumptions and limitations.**
- **The data measures total time in the pit lane, not the stationary time in the box.** A stop includes
  the entry and exit. A stationary time of about 2–3 seconds is not in the data, and nothing here can
  reach it. Pit lane speed limits and pit lane lengths both change the total, and neither is in the data.
- **No stop reasons.** Tyre changes, repairs, penalty stops and safety-car stops all appear as stops.
  A rise in repair or penalty stops would make the tail heavier without any change in the box.
- **Circuit baseline uses only circuits with at least 8 seasons.** Circuits that hosted races for fewer
  seasons are excluded from the adjusted series, and their stops are not in it.
- **Red flags are excluded at 60 seconds.** Safety-car periods are not identified, so stops made under
  them are included without adjustment.
- **2020 had a reduced calendar** (17 races, 532 stops), which changes the mix for that season.
- Data starts in 2011, so nothing earlier can be compared.

**Where the question misleads.** "Faster" is ambiguous. Pit lane time is not what decides a race. The
time lost against staying on track is what matters, and that depends on the pit lane's length, which
this data does not have. A stop can get "slower" in the data and still cost the same time overall. The
honest answer is that this data cannot say whether teams are losing less time in the pits, only that the
recorded pit lane time has not fallen.
