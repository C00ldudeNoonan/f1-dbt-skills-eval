-- Pole sitter has a zero gap; nobody has a negative gap; times only null together.
select qualify_id from {{ ref('fct_qualifying') }}
where gap_to_pole_ms < 0
   or (best_time_ms is null) <> (gap_to_pole_ms is null)
   or best_time_ms > coalesce(q1_ms, 2147483647) and q1_ms is not null
