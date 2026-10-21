{#
    One row per qualifying entry.
    best_time_ms is the fastest of Q1, Q2 and Q3. Snowflake LEAST returns NULL
    when any argument is NULL, so NULLs are replaced with a sentinel first.
    Gaps are measured against the fastest best_time_ms in the same race.
#}
with qualifying as (

    select * from {{ ref('stg_f1__qualifying') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

with_best as (

    select
        qualifying.*,
        races.season,
        nullif(
            least(
                coalesce(q1_ms, 2147483647),
                coalesce(q2_ms, 2147483647),
                coalesce(q3_ms, 2147483647)
            ),
            2147483647
        ) as best_time_ms

    from qualifying
    inner join races
        on qualifying.race_id = races.race_id

),

with_pole as (

    select
        with_best.*,
        min(best_time_ms) over (partition by race_id) as pole_time_ms

    from with_best

)

select
    qualify_id,
    race_id,
    season,
    driver_id,
    constructor_id,
    position,
    q1_ms,
    q2_ms,
    q3_ms,
    best_time_ms,
    best_time_ms - pole_time_ms as gap_to_pole_ms,
    (best_time_ms - pole_time_ms) / pole_time_ms * 100 as gap_to_pole_pct

from with_pole
