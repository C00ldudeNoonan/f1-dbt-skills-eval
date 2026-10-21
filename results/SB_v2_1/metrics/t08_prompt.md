Next: the analysts want to self-serve through the dbt Semantic Layer instead of asking us for new marts.

Define semantic models and these metrics, with these exact names:
- `race_starts`: count of Grand Prix result entries
- `wins`: Grand Prix wins
- `podiums`: Grand Prix podiums
- `championship_points`: sum of Grand Prix points
- `podium_rate`: podiums divided by race starts
- `points_per_start`: championship points divided by race starts

They need to slice these by season, driver, driver nationality, and constructor, and over time by race date. Set up whatever the Semantic Layer needs for that to work. Make sure `dbt build` (and parsing) succeeds when you're done, and give a few example queries an analyst could run.
