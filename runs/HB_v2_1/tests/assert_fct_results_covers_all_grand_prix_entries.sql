{#
    fct_results must hold every Grand Prix result from the source and nothing else.
    Sprint results are excluded by design.
#}
with source_count as (

    select count(*) as source_rows
    from {{ source('f1_raw', 'results') }}

),

model_count as (

    select count(*) as model_rows
    from {{ ref('fct_results') }}

)

select *
from source_count
cross join model_count
where source_rows <> model_rows
