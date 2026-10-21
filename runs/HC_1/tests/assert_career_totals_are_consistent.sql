-- A driver cannot have more wins than podiums, or more podiums than starts.
select
    driver_id,
    career_starts,
    career_wins,
    career_podiums
from {{ ref('dim_drivers') }}
where career_wins > career_podiums
    or career_podiums > career_starts
