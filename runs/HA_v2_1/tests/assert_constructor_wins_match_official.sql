{#
    Constructor wins per season must equal the official constructor standings. A duplicated
    constructor or a duplicated result entry shows up here as extra wins.
#}
with ours as (

    select season, constructor_id, count_if(is_win) as wins
    from {{ ref('fct_results') }}
    group by season, constructor_id

),

official as (

    select
        races.season,
        standings.constructor_id,
        standings.wins,
        row_number() over (
            partition by races.season, standings.constructor_id
            order by races.round desc
        ) as rn
    from {{ ref('stg_f1__constructor_standings') }} as standings
    inner join {{ ref('stg_f1__races') }} as races
        on standings.race_id = races.race_id

)

select ours.season, ours.constructor_id, ours.wins as our_wins, official.wins as official_wins
from ours
inner join official
    on ours.season = official.season
    and ours.constructor_id = official.constructor_id
    and official.rn = 1
where ours.wins <> official.wins
