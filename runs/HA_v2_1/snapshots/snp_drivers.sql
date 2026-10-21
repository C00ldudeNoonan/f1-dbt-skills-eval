{#
    Type 2 history of driver reference data. A new row is written whenever a tracked
    attribute changes (car number, code, name, nationality, date of birth), so the
    history of a driver's numbers and codes can be reconstructed with dbt_valid_from
    and dbt_valid_to. The raw feed holds only current values, so history starts at
    the first snapshot run.
#}
{% snapshot snp_drivers %}

{{
    config(
        unique_key='driver_id',
        strategy='check',
        check_cols=[
            'driver_ref',
            'permanent_number',
            'driver_code',
            'forename',
            'surname',
            'date_of_birth',
            'nationality'
        ]
    )
}}

select * from {{ ref('stg_f1__drivers') }}

{% endsnapshot %}
