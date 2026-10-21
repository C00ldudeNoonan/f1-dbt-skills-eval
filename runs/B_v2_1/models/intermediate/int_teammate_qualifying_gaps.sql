{#-
  One row per race, constructor, driver and teammate (both orderings) where
  both drivers set a time in a common qualifying session.

  Times are compared within one session: the latest session both drivers set
  a time in (Q3, else Q2, else Q1). Comparing best times across sessions would
  mix track evolution and fuel/tyre differences into the gap.

  is_representative flags gaps within +/-3%. Larger gaps almost always mean
  something other than pace (a crash or a failure mid-lap, rain arriving
  between runs, a car that didn't run properly), so they are excluded from
  pace estimates but kept here for transparency.
-#}
with qualifying as (
    select * from {{ ref('fct_qualifying') }}
),

pairs as (
    select
        driver.race_id,
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        case
            when driver.q3_ms is not null and teammate.q3_ms is not null then 'Q3'
            when driver.q2_ms is not null and teammate.q2_ms is not null then 'Q2'
            when driver.q1_ms is not null and teammate.q1_ms is not null then 'Q1'
        end as session_compared,
        case session_compared
            when 'Q3' then driver.q3_ms when 'Q2' then driver.q2_ms when 'Q1' then driver.q1_ms
        end as driver_time_ms,
        case session_compared
            when 'Q3' then teammate.q3_ms when 'Q2' then teammate.q2_ms when 'Q1' then teammate.q1_ms
        end as teammate_time_ms
    from qualifying as driver
    inner join qualifying as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
)

select
    *,
    (100 * (driver_time_ms - teammate_time_ms) / teammate_time_ms)::number(8, 4) as gap_pct,
    abs(gap_pct) <= 3 as is_representative
from pairs
where session_compared is not null
