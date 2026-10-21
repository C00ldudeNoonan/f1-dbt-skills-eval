{#
    Every pairing of a Vendor B session with one of our race weekends in the same season and at
    the same location, where the session date is within one day of the race (or sprint) date.
    Vendor B dates are UTC and ours are local, so one day of tolerance is needed.
    days_apart is the distance used to pick the closest match.
#}
with vb as (

    select
        session_key,
        session_type,
        season,
        {{ normalize_text('meeting_name') }} as location_key,
        session_date

    from {{ ref('stg_vendor_b__sessions') }}

),

races as (

    select
        races.race_id,
        races.season,
        races.race_date,
        races.sprint_date,
        {{ normalize_text('circuits.location') }} as location_key

    from {{ ref('stg_f1__races') }} as races
    inner join {{ ref('stg_f1__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id

),

pairs as (

    select
        vb.session_key,
        vb.session_type,
        races.race_id,
        case vb.session_type
            when 'race' then abs(datediff(day, vb.session_date, races.race_date))
            when 'sprint' then abs(datediff(day, vb.session_date, races.sprint_date))
        end as days_apart

    from vb
    inner join races
        on vb.season = races.season
        and vb.location_key = races.location_key

)

select *
from pairs
where days_apart <= 1
