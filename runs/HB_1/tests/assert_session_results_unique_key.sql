select
    session_type,
    source_result_id,
    count(*) as row_count
from {{ ref('fct_session_results') }}
group by session_type, source_result_id
having count(*) > 1
