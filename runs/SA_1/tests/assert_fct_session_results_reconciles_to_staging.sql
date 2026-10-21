select 'race' as session_type, count(*) as n, (select count(*) from {{ ref('stg_results') }}) as expected
from {{ ref('fct_session_results') }} where session_type = 'race'
having count(*) <> (select count(*) from {{ ref('stg_results') }})
union all
select 'sprint', count(*), (select count(*) from {{ ref('stg_sprint_results') }})
from {{ ref('fct_session_results') }} where session_type = 'sprint'
having count(*) <> (select count(*) from {{ ref('stg_sprint_results') }})
