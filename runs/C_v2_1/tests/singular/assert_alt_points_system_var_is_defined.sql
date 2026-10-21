-- mart_alt_points_standings filters on the alt_points_system var. If the var
-- names a system that isn't in the points_systems seed, the mart would be
-- silently empty, so fail instead.
select '{{ var("alt_points_system", "fia_2010") }}' as missing_points_system
where not exists (
    select 1
    from {{ ref('points_systems') }}
    where points_system = '{{ var("alt_points_system", "fia_2010") }}'
)
