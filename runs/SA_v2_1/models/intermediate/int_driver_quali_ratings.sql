{{ config(materialized='table') }}

{{ speed_ratings(ref('int_teammate_qualifying_gaps')) }}
