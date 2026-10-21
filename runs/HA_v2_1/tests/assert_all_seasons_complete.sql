{#
    Every season in the raw data is complete: each calendar race has results. The 2024 gap
    that existed earlier is closed. If a season becomes incomplete (for example a vendor
    feed missing results), this test fails so the change is reviewed before it reaches
    championship figures.
#}
select season
from {{ ref('int_season_completeness') }}
where not is_season_complete
