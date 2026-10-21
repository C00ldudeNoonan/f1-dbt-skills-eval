{% docs f1_overview %}
# F1 analytics

dbt project modelling the Ergast/Kaggle Formula 1 dataset (1950 to the current
season) for the F1 analytics team and downstream consumers.

Layers:
- **staging** (`stg_f1__*`, views): one model per raw table. Types the text
  columns, turns the `\N` sentinel and empty strings into nulls, renames to
  snake_case. No business logic.
- **intermediate** (`int_f1__*`, views): shared building blocks, such as the
  race calendar with completion flags.
- **marts** (tables, public, contract-enforced): the models other teams build on.
{% enddocs %}

{% docs col_season %}
Championship year (for example 2024).
{% enddocs %}

{% docs col_race_id %}
Ergast race id. One per Grand Prix; sprints share their weekend's race id.
{% enddocs %}

{% docs col_driver_id %}
Ergast driver id. Joins to `dim_drivers.driver_id`.
{% enddocs %}

{% docs col_constructor_id %}
Ergast constructor id. Renamed or rebranded teams get new ids (Toro Rosso and
AlphaTauri are different constructors).
{% enddocs %}

{% docs col_position_order %}
Ergast's total ordering of every entry in the race, including retirements and
non-starters (lower is better). Always populated, unlike `finish_position`.
Shared cars before 1979 can share a value.
{% enddocs %}

{% docs col_finish_position %}
Official classified finishing position. Null when the car was not classified
(retired, disqualified, excluded, withdrew, did not qualify, not classified).
Derived from the classification text, because a couple of classified finishers
(2005 Australian GP, P11 and P14) have a null raw position.
{% enddocs %}

{% docs col_is_season_complete %}
True when every race on the season's calendar has results. Championships only
count once their season is complete.
{% enddocs %}
