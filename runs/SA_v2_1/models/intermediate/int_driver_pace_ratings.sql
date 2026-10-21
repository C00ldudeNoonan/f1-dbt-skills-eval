{{ config(materialized='table') }}

{{ speed_ratings(ref('int_teammate_pace_gaps')) }}
