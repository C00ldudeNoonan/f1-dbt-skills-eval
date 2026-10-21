{% snapshot snp_drivers %}

{#-
    Type 2 history of the raw drivers table. Each change to a tracked attribute closes the old row
    (dbt_valid_to) and opens a new one. The source only holds current values, so history starts at the
    first snapshot run and earlier changes cannot be recovered from this table.
-#}
{{
    config(
        target_schema=target.schema ~ '_snapshots',
        unique_key='driverid',
        strategy='check',
        check_cols=['driverref', 'number', 'code', 'forename', 'surname', 'dob', 'nationality']
    )
}}

select * from {{ source('f1_raw', 'drivers') }}

{% endsnapshot %}
