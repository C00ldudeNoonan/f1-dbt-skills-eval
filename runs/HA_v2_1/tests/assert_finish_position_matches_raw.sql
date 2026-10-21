{#
    Where the raw POSITION column is populated, finish_position must equal it.
    Guards the rule that finish_position is read from position text.
#}
select fct_results.result_id
from {{ ref('fct_results') }} as fct_results
inner join {{ ref('stg_f1__results') }} as raw_results
    on fct_results.result_id = raw_results.result_id
where raw_results.position_number is not null
    and fct_results.finish_position <> raw_results.position_number
