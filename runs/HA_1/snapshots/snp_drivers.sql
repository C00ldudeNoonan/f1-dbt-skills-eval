-- Type 2 history of the raw drivers table. Each change to a driver's attributes
-- (for example permanent number or code) closes the old row and opens a new one.
--
-- The raw table only holds current values, so history starts on the first run.
-- Changes made before that cannot be reconstructed from this source.

{% snapshot snp_drivers %}

{{
    config(
        target_schema=target.schema ~ '_snapshots',
        unique_key='driverid',
        strategy='check',
        check_cols='all'
    )
}}

select * from {{ source('f1_raw', 'drivers') }}

{% endsnapshot %}
