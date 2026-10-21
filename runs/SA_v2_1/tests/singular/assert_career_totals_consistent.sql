select driver_id
from {{ ref('dim_drivers') }}
where career_wins > career_podiums
    or career_podiums > career_starts
