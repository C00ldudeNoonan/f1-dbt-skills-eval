-- Every raw GP and sprint result row appears exactly once, in the right session type.
select 1
from (
    select
        (select count(*) from {{ source('f1_raw', 'results') }}) as raw_race,
        (select count(*) from {{ source('f1_raw', 'sprint_results') }}) as raw_sprint,
        (select count(*) from {{ ref('fct_session_results') }} where session_type = 'race') as fct_race,
        (select count(*) from {{ ref('fct_session_results') }} where session_type = 'sprint') as fct_sprint
)
where raw_race <> fct_race or raw_sprint <> fct_sprint
