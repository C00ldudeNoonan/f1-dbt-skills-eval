{#
    Classification rules:
      - a classified entry has a finish position, and an unclassified one does not
      - a winner is the entry with finish_position 1
      - a podium is a finish of 1, 2 or 3
#}
select
    result_id,
    finish_position,
    is_classified,
    is_win,
    is_podium

from {{ ref('fct_results') }}
where (is_classified <> (finish_position is not null))
    or (is_win <> coalesce(finish_position = 1, false))
    or (is_podium <> coalesce(finish_position between 1 and 3, false))
    or (finish_position is not null and finish_position < 1)
