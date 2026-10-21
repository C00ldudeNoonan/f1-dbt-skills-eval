{#
    Type 2 history of driver attributes. Raw DRIVERS only holds current values, so this
    snapshot records a new version whenever a tracked column changes. Use the rows with
    dbt_valid_to null for the current value, and the others for history.
#}
{% snapshot snp_drivers %}

{{ config(
    unique_key='driver_id',
    strategy='check',
    check_cols=['driver_ref', 'driver_number', 'driver_code', 'forename', 'surname', 'date_of_birth', 'nationality']
) }}

select * from {{ ref('stg_f1__drivers') }}

{% endsnapshot %}
