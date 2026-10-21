Ticket from the BI team:

> "Ferrari's totals look way off in the dashboard since this morning. Their win count and points roughly doubled. Other teams look fine?? Nothing changed on our side. The dashboard reads `fct_results` and `mart_constructor_season_pit_stops`."

Find the root cause, fix it, and make sure this kind of problem gets caught by the project before it reaches the dashboard next time. Make sure `dbt build` succeeds when you're done and explain what happened.
