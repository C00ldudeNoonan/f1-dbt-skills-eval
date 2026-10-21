-- Seasons covered by Vendor B, derived from its own sessions so new seasons are picked up automatically.
select min(season) as first_season, max(season) as last_season
from {{ ref('stg_f1__vb_sessions') }}
