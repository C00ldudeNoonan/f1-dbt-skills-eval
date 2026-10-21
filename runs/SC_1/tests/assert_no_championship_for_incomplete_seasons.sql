-- Titles total must equal the number of complete seasons that have standings.
select 1
from (
    select
        (select sum(world_championships) from {{ ref('dim_drivers') }}) as titles,
        (select count(*) from {{ ref('int_f1__season_status') }} where is_season_complete) as complete_seasons
)
where titles <> complete_seasons
