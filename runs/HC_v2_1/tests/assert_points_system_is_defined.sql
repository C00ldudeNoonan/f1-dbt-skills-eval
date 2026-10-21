{#
    The points_system var must name a system in the points_systems seed. An unknown name would score every
    driver zero without any error, so this test fails instead.
#}
select '{{ var("points_system") }}' as missing_system
where not exists (
    select 1
    from {{ ref('points_systems') }}
    where system_name = '{{ var("points_system") }}'
)
