{#
    Type 2 history of the drivers table. A new row is written whenever a tracked attribute changes,
    so car numbers and codes keep their history. The raw drivers table holds only current values,
    so history starts with the first run of this snapshot.
#}
{% snapshot snp_drivers %}

{{
    config(
        target_schema=target.schema ~ '_snapshots',
        unique_key='driver_id',
        strategy='check',
        check_cols='all'
    )
}}

select * from {{ ref('stg_f1__drivers') }}

{% endsnapshot %}
