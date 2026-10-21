with races as (
    select * from {{ ref('stg_ergast__races') }}
),

circuits as (
    select * from {{ ref('stg_ergast__circuits') }}
),

completed as (
    select distinct race_id from {{ ref('stg_ergast__results') }}
)

select
    races.race_id,
    races.season,
    races.round,
    races.race_name,
    races.race_date,
    races.circuit_id,
    circuits.circuit_name,
    circuits.country,
    races.has_sprint,
    completed.race_id is not null as is_completed
from races
left join circuits
    on races.circuit_id = circuits.circuit_id
left join completed
    on races.race_id = completed.race_id
