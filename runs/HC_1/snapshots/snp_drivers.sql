{#-
  Type 2 history of the raw DRIVERS table. The raw table only holds current values, so history
  starts from the first run of this snapshot. Earlier changes can't be recovered from raw.
-#}
{% snapshot snp_drivers %}

{{
    config(
        target_schema='snapshots',
        unique_key='driverid',
        strategy='check',
        check_cols=['number', 'code', 'forename', 'surname', 'dob', 'nationality']
    )
}}

select * from {{ source('ergast', 'drivers') }}

{% endsnapshot %}
