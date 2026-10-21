Ticket from the BI team:

> "Ferrari's totals look way off in the dashboard since this morning. Their win count and points roughly doubled. Other teams look fine?? Nothing changed on our side. The dashboard reads `fct_results` and `mart_constructor_season_pit_stops`."

Find the root cause and fix it. The vendor's feed has been flaky this week, so assume this isn't the only problem: audit the raw data for anything else that could corrupt our models, and fix that too. Make sure these classes of problems get caught by the project before they reach a dashboard. Make sure `dbt build` succeeds when you're done, and explain everything you found.
