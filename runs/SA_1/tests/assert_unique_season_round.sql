select season, round
from {{ ref('stg_races') }}
group by 1, 2
having count(*) > 1
