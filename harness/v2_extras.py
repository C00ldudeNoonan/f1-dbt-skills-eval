"""Generators and answer-key helpers for v2 tasks 9-11 (vendor B feed, telemetry, slim CI).

The vendor-B id mapping and the planted conflicts are pure functions of the source rows and a
secret salt (EVAL_SALT in config.env). The grader recomputes them, so no answer table ever
exists in Snowflake for an agent to find.
"""
from sf import CFG

SALT = CFG.get("EVAL_SALT", "salt")
NN = "chr(92) || 'N'"
VB_YEARS = "between 2018 and 2024"
ACCENTS = ("translate({x}, 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÉÈÍÓÖÚÜÑÇ', "
           "'aaaaaeeeeiiiiooooouuuuncAAAEEIOOUUNC')")


def vb_driver_key(expr):
    return f"'DRV' || lpad((abs(hash({expr}, '{SALT}')) % 900000 + 100000)::varchar, 6, '0')"


def vb_session_key(race_expr, kind_expr):
    return f"(abs(hash({race_expr}, {kind_expr}, '{SALT}')) % 9000000 + 1000000)"


def vb_entries(T):
    """Primary-feed entries in vendor B's scope, with deterministic conflict ranks."""
    return f"""
    with vb_a as (
      select 'race' st, r.raceid, r.driverid, r.constructorid, r.grid, r.position, r.points, r.statusid
      from {T}.results r join {T}.races ra on ra.raceid = r.raceid where ra.year::int {VB_YEARS}
      union all
      select 'sprint', s.raceid, s.driverid, s.constructorid, s.grid, s.position, s.points, s.statusid
      from {T}.sprint_results s join {T}.races ra on ra.raceid = s.raceid where ra.year::int {VB_YEARS}),
    vb_h as (select vb_a.*, try_to_number(nullif(position, {NN})) fp,
            row_number() over (order by abs(hash(st, raceid, driverid, '{SALT}'))) rn
          from vb_a)
    select vb_h.*, iff(fp is not null and rn > 7,
                    row_number() over (partition by (fp is not null and rn > 7) order by abs(hash(st, raceid, driverid, '{SALT}p'))),
                    null) rn_pos
    from vb_h"""


def gen_vendor_b(conn, src, dests, run):
    """Write VB_DRIVERS / VB_SESSIONS / VB_RESULTS into each schema in dests, generated from src."""
    strip = lambda x: ACCENTS.format(x=x)
    stmts = {
        "vb_drivers": f"""
            select {vb_driver_key('d.driverid')} driver_key,
              upper({strip('d.surname')}) || ' ' || iff(d.driverref = 'albon', 'Alex', {strip('d.forename')}) full_name,
              nullif(d.code, {NN}) abbreviation, try_to_number(nullif(d.number, {NN})) racing_number
            from {src}.drivers d
            where d.driverid in (select driverid from ({vb_entries(src)}))""",
        "vb_sessions": f"""
            select {vb_session_key('ra.raceid', "'race'")} session_key, 'Race' session_type, ci.location meeting_name,
              ra.year::int year, ra.date || 'T' || ra.time || 'Z' date_start
            from {src}.races ra join {src}.circuits ci on ci.circuitid = ra.circuitid
            where ra.year::int {VB_YEARS} and ra.raceid in (select raceid from {src}.results)
            union all
            select {vb_session_key('ra.raceid', "'sprint'")}, 'Sprint', ci.location, ra.year::int,
              ra.sprint_date || 'T' || ra.sprint_time || 'Z'
            from {src}.races ra join {src}.circuits ci on ci.circuitid = ra.circuitid
            where ra.year::int {VB_YEARS} and ra.raceid in (select raceid from {src}.sprint_results)""",
        # rn 1-3 dropped (missing in B), rn 4-7 points +1, rn_pos 1-4 classified position +1
        "vb_results": f"""
            select {vb_session_key('e.raceid', 'e.st')} session_key, {vb_driver_key('e.driverid')} driver_key,
              c.name team_name, try_to_number(e.grid)::int grid_position,
              case when e.rn_pos <= 4 then (e.fp + 1)::varchar
                   when e.fp is not null then e.fp::varchar
                   when e.statusid = '2' then 'DSQ' else 'DNF' end position,
              (try_to_double(e.points) + iff(e.rn between 4 and 7, 1, 0))::number(5, 1) points
            from ({vb_entries(src)}) e join {src}.constructors c on c.constructorid = e.constructorid
            where e.rn > 3""",
    }
    for d in dests:
        for t, sql in stmts.items():
            run(conn, f"create or replace table {d}.{t} as {sql}")
    n = run(conn, f"select count(*), count(distinct driver_key) from {dests[0]}.vb_drivers")[0]
    assert n[0] == n[1], f"vendor B driver key collision: {n}"


def ak_driver_crosswalk(T):
    return f"""
    select v.driver_key, d.driverid::int driver_id
    from {T}.vb_drivers v join {T}.drivers d on {vb_driver_key('d.driverid')} = v.driver_key"""


def ak_session_crosswalk(T):
    return f"""
    select {vb_session_key('ra.raceid', "'race'")} session_key, ra.raceid::int race_id, 'race' session_type
    from {T}.races ra where ra.year::int {VB_YEARS} and ra.raceid in (select raceid from {T}.results)
    union all
    select {vb_session_key('ra.raceid', "'sprint'")}, ra.raceid::int, 'sprint'
    from {T}.races ra where ra.year::int {VB_YEARS} and ra.raceid in (select raceid from {T}.sprint_results)"""


def ak_discrepancies(T):
    return f"""
    with a as (select st, raceid::int race_id, driverid::int driver_id, fp, try_to_double(points) pts from ({vb_entries(T)})),
    smap as ({ak_session_crosswalk(T)}),
    dmap as (select {vb_driver_key('driverid')} driver_key, driverid::int driver_id from {T}.drivers),
    b as (select s.session_type st, s.race_id, d.driver_id, try_to_number(v.position) fp, v.points::float pts
          from {T}.vb_results v join smap s on s.session_key = v.session_key join dmap d on d.driver_key = v.driver_key),
    j as (select coalesce(a.race_id, b.race_id) race_id, coalesce(a.st, b.st) session_type,
            coalesce(a.driver_id, b.driver_id) driver_id, a.race_id is not null in_a, b.race_id is not null in_b,
            a.fp afp, b.fp bfp, a.pts apts, b.pts bpts
          from a full outer join b on a.race_id = b.race_id and a.st = b.st and a.driver_id = b.driver_id)
    select race_id, session_type, driver_id, 'missing_in_vendor_b' discrepancy_type from j where in_a and not in_b
    union all select race_id, session_type, driver_id, 'missing_in_vendor_a' from j where in_b and not in_a
    union all select race_id, session_type, driver_id, 'points' from j where in_a and in_b and abs(apts - bpts) > 0.001
    union all select race_id, session_type, driver_id, 'position' from j where in_a and in_b and not equal_null(afp, bfp)"""


# ---------- telemetry ----------
SAMPLES_PER_LAP = 270
LATE = "raceid = 1142 and lap between 20 and 30 and mod(driverid, 3) = 0"
LATE_OR_NEW = f"(raceid = 1144 or ({LATE}))"


def gen_telemetry(conn, src, dest, run):
    """~20M samples for 2022+ laps. Deterministic pseudo-random channels from hashes."""
    run(conn, f"""
    create or replace table {dest}.car_telemetry as
    with l as (
      select l.raceid::int raceid, l.driverid::int driverid, l.lap::int lap, l.milliseconds::int ms,
        timestampadd(ms, sum(l.milliseconds::int) over (partition by l.raceid, l.driverid order by l.lap::int)
                         - l.milliseconds::int, (ra.date || ' ' || ra.time)::timestamp_ntz) lap_start
      from {src}.lap_times l join {src}.races ra on ra.raceid = l.raceid where ra.year::int >= 2022),
    g as (select row_number() over (order by seq4()) - 1 i from table(generator(rowcount => {SAMPLES_PER_LAP}))),
    x as (select l.*, g.i, abs(hash(l.raceid, l.driverid, l.lap, g.i, 'tel')) h from l cross join g)
    select raceid, driverid, lap, i sample_index,
      timestampadd(ms, floor(ms * i / {SAMPLES_PER_LAP}), lap_start) recorded_at,
      round(70 + mod(h, 2550) / 10.0, 1) speed_kph,
      mod(floor(h / 7), 101)::int throttle_pct,
      mod(floor(h / 7), 101) < 8 brake,
      least(8, 1 + floor((70 + mod(h, 2550) / 10.0) / 40))::int gear,
      iff(mod(floor(h / 11), 9) = 0, 1, 0) drs,
      timestampadd(hour, 2, timestampadd(ms, floor(ms * i / {SAMPLES_PER_LAP}), lap_start)) _loaded_at
    from x""")


def ak_lap_telemetry(T):
    return f"""
    select raceid race_id, driverid driver_id, lap, count(*) samples, max(speed_kph) max_speed_kph,
      avg(throttle_pct) avg_throttle_pct, count_if(throttle_pct >= 99) / count(*) * 100 full_throttle_pct,
      count_if(brake) brake_samples
    from {T}.car_telemetry group by 1, 2, 3"""
