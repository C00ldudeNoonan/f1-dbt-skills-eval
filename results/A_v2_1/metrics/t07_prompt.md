`dim_drivers` and `fct_results` are now consumed by another team's dbt project, so we need to treat them as public interfaces.

1. Put both models in a group that our team owns, make them `public`, and keep everything else in the project at the default or `protected` access.
2. Enforce model contracts on `fct_results` and `dim_drivers`.
3. The other team wants `full_name` replaced by separate `first_name` and `last_name` columns in `dim_drivers`. That's a breaking change, so ship it as **version 2** of `dim_drivers`. Keep version 1 available and building, mark it deprecated on 2027-01-01, and make version 2 the latest. Placeholder rows for late-arriving drivers must keep working in both versions.
4. Add dbt unit tests covering at least (a) the fastest-lap time parsing, (b) the "a championship only counts once the season is complete" logic, (c) the stint boundary logic, and (d) the alt-points countback tie-break.

Make sure `dbt build` succeeds when you're done, and summarize what a consumer needs to know about the change.
