{#
    fct_results must have exactly one row per staged Grand Prix result, with the same points and win totals.
    A join that fans out (for example to a constructor or standings table with duplicate keys) doubles wins and
    points for whichever team is duplicated. This test catches that before a dashboard reads it.
#}
with source_totals as (

    select
        count(*) as result_rows,
        count(distinct result_id) as distinct_results,
        sum(points) as total_points,
        count_if({{ classified_finish_position('position', 'position_text') }} = 1) as wins
    from {{ ref('stg_f1__results') }}

),

model_totals as (

    select
        count(*) as result_rows,
        count(distinct result_id) as distinct_results,
        sum(points) as total_points,
        count_if(is_win) as wins
    from {{ ref('fct_results') }}

)

select
    source_totals.result_rows as source_rows,
    model_totals.result_rows as model_rows,
    source_totals.wins as source_wins,
    model_totals.wins as model_wins,
    source_totals.total_points as source_points,
    model_totals.total_points as model_points
from source_totals
cross join model_totals
where model_totals.result_rows <> source_totals.result_rows
    or model_totals.distinct_results <> source_totals.distinct_results
    or model_totals.total_points <> source_totals.total_points
    or model_totals.wins <> source_totals.wins
