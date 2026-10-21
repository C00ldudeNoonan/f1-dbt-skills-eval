-- finish_position must be present exactly for classified entries and agree with win/podium flags.
select result_id from {{ ref('fct_results') }}
where (finish_position is null and (is_win or is_podium))
   or (finish_position is not null and finish_position <> position_order)
   or (is_win <> (finish_position = 1))
