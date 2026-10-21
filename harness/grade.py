"""Grade a run after a task.

usage: grade.py RUN_ID TASK_NUM PHASE [--build]
  PHASE   label for the results file ("agent" = state the agent left, "rebuild" = after the
          harness injected new data and re-ran dbt build itself)
  --build run `dbt build` (never --full-refresh) in the project before checking

Answer keys are computed from the run's truth schema, which only receives legitimate data
changes. Agent outputs are located through target/manifest.json, so custom schemas, aliases,
and versioned models resolve correctly. Writes results/RUN_ID/grades/tNN_PHASE.json.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

from sf import CFG, ROOT, connect, run, run_schemas
import v2_extras as vx


def nn(c):
    return f"nullif({c}, chr(92) || 'N')"


def num(c):
    return f"try_to_double({nn(c)})"


def lap_ms(c):
    t = nn(c)
    return (f"round(iff(contains({t}, ':'), split_part({t}, ':', 1)::int * 60000 "
            f"+ try_to_double(split_part({t}, ':', 2)) * 1000, try_to_double({t}) * 1000))")


def pos(c):
    return f"try_to_number({nn(c)})"


# ---------- answer keys (T = truth schema) ----------

def ak_fct_results(T):
    p = pos("r.position")
    return f"""
    select r.resultid::int result_id, r.raceid::int race_id, ra.year::int season, ra.round::int round,
      ra.date::date race_date, r.driverid::int driver_id, r.constructorid::int constructor_id,
      c.name constructor_name, {num('r.grid')} grid, {p} finish_position,
      r.positionorder::int position_order, {num('r.points')} points, {num('r.laps')} laps,
      st.status status, iff({p} = 1, 1, 0) is_win, iff({p} <= 3, 1, 0) is_podium,
      {lap_ms('r.fastestlaptime')} fastest_lap_time_ms
    from {T}.results r
    join {T}.races ra on ra.raceid = r.raceid
    join {T}.constructors c on c.constructorid = r.constructorid
    left join {T}.status st on st.statusid = r.statusid"""


def ak_standings_by_round(T):
    return f"""
    select ra.year::int season, ra.round::int round, ds.raceid::int race_id, ds.driverid::int driver_id,
      {pos('ds.position')} championship_position, {num('ds.points')} points, {num('ds.wins')} wins
    from {T}.driver_standings ds join {T}.races ra on ra.raceid = ds.raceid"""


def ak_season_standings(T):
    return f"""
    select season, driver_id, championship_position, points, wins
    from ({ak_standings_by_round(T)})
    qualify round = max(round) over (partition by season)"""


def ak_dim_drivers(T, version=1):
    p = pos("r.position")
    names = ("d.forename || ' ' || d.surname full_name" if version == 1
             else "d.forename first_name, d.surname last_name")
    return f"""
    with res as (
      select r.driverid::int driver_id, count(distinct r.raceid) starts,
        count_if({p} = 1) wins, count_if({p} <= 3) podiums,
        count(distinct iff({p} <= 3, r.raceid, null)) podium_races
      from {T}.results r group by 1),
    spr as (
      select s.driverid::int driver_id, count_if({pos('s.position')} = 1) sprint_wins
      from {T}.sprint_results s group by 1),
    cal as (select year::int season, count(*) n from {T}.races group by 1),
    done as (select ra.year::int season, count(distinct r.raceid) n
             from {T}.results r join {T}.races ra on ra.raceid = r.raceid group by 1),
    complete as (select cal.season from cal join done on cal.season = done.season and cal.n = done.n),
    final as ({ak_season_standings(T)}),
    champs as (select driver_id, count(*) titles from final
               where championship_position = 1 and season in (select season from complete) group by 1)
    select d.driverid::int driver_id, d.driverref driver_ref, {names}, d.nationality,
      decode(trim(d.nationality), 'Argentinian', 'Argentine', trim(d.nationality)) nationality__alt,
      try_to_date({nn('d.dob')}) date_of_birth,
      coalesce(res.starts, 0) career_starts, coalesce(res.wins, 0) career_wins,
      coalesce(res.podiums, 0) career_podiums, coalesce(res.podium_races, 0) career_podiums__alt,
      coalesce(champs.titles, 0) world_championships,
      {pos('d.number')} current_number, coalesce(spr.sprint_wins, 0) career_sprint_wins
    from {T}.drivers d
    left join res on res.driver_id = d.driverid::int
    left join spr on spr.driver_id = d.driverid::int
    left join champs on champs.driver_id = d.driverid::int"""


def ak_pit_stops(T):
    return f"""
    select ra.year::int season, r.constructorid::int constructor_id, count(*) pit_stop_count,
      median(ps.milliseconds::int / 1000.0) median_pit_stop_seconds
    from {T}.pit_stops ps
    join {T}.races ra on ra.raceid = ps.raceid
    join (select distinct raceid, driverid, constructorid from {T}.results) r
      on r.raceid = ps.raceid and r.driverid = ps.driverid
    where ps.milliseconds::int <= 60000
    group by 1, 2"""


def ak_lap_times(T):
    return f"""
    select l.raceid::int race_id, ra.year::int season, ra.round::int round, l.driverid::int driver_id,
      l.lap::int lap, {pos('l.position')} position, l.milliseconds::int lap_time_ms
    from {T}.lap_times l join {T}.races ra on ra.raceid = l.raceid"""


def ak_session_results(T):
    def part(kind, tbl):
        return f"""
        select '{kind}' session_type, x.resultid::int source_result_id, x.raceid::int race_id,
          ra.year::int season, ra.round::int round, x.driverid::int driver_id,
          x.constructorid::int constructor_id, {pos('x.position')} finish_position, {num('x.points')} points
        from {T}.{tbl} x join {T}.races ra on ra.raceid = x.raceid"""
    return part("race", "results") + " union all " + part("sprint", "sprint_results")


# ---------- v2 answer keys ----------

def ak_qualifying(T):
    big = "1e15"
    return f"""
    with q as (
      select x.qualifyid::int qualify_id, x.raceid::int race_id, x.driverid::int driver_id,
        x.constructorid::int constructor_id, {lap_ms('x.q1')} q1_ms, {lap_ms('x.q2')} q2_ms, {lap_ms('x.q3')} q3_ms
      from {T}.qualifying x),
    b as (select *, nullif(least(coalesce(q1_ms, {big}), coalesce(q2_ms, {big}), coalesce(q3_ms, {big})), {big}) best_time_ms from q)
    select *, best_time_ms - min(best_time_ms) over (partition by race_id) gap_to_pole_ms,
      (best_time_ms - min(best_time_ms) over (partition by race_id)) / min(best_time_ms) over (partition by race_id) * 100
        gap_to_pole_pct
    from b"""


def ak_teammates(T):
    return f"""
    with r as (
      select ra.year::int season, x.raceid::int race_id, x.constructorid::int constructor_id,
        x.driverid::int driver_id, min(x.positionorder::int) best_po
      from {T}.results x join {T}.races ra on ra.raceid = x.raceid group by 1, 2, 3, 4),
    q as (
      select ra.year::int season, x.raceid::int race_id, x.constructorid::int constructor_id,
        x.driverid::int driver_id, min({pos('x.position')}) qpos
      from {T}.qualifying x join {T}.races ra on ra.raceid = x.raceid group by 1, 2, 3, 4),
    rp as (
      select a.season, a.constructor_id, a.driver_id, b.driver_id teammate_id,
        count(distinct a.race_id) races_together, count_if(a.best_po < b.best_po) races_ahead
      from r a join r b on a.race_id = b.race_id and a.constructor_id = b.constructor_id and a.driver_id <> b.driver_id
      group by 1, 2, 3, 4),
    qp as (
      select a.season, a.constructor_id, a.driver_id, b.driver_id teammate_id,
        count(distinct a.race_id) qualifying_together, count_if(a.qpos < b.qpos) qualifying_ahead
      from q a join q b on a.race_id = b.race_id and a.constructor_id = b.constructor_id and a.driver_id <> b.driver_id
      group by 1, 2, 3, 4)
    select rp.*, coalesce(qp.qualifying_together, 0) qualifying_together, coalesce(qp.qualifying_ahead, 0) qualifying_ahead
    from rp left join qp using (season, constructor_id, driver_id, teammate_id)"""


def _laps(T):
    return f"select raceid::int race_id, driverid::int driver_id, lap::int lap, milliseconds::int ms from {T}.lap_times"


def ak_race_pace(T):
    return f"""
    with l as ({_laps(T)}),
    fast as (select race_id, min(ms) f from l group by 1),
    p as (select raceid::int race_id, driverid::int driver_id, lap::int lap from {T}.pit_stops),
    bad as (select race_id, driver_id, lap from p union select race_id, driver_id, lap + 1 from p)
    select l.race_id, l.driver_id, count(*) green_laps, median(l.ms) median_green_lap_ms
    from l join fast on fast.race_id = l.race_id
    left join bad on bad.race_id = l.race_id and bad.driver_id = l.driver_id and bad.lap = l.lap
    where l.lap <> 1 and l.ms <= 1.3 * fast.f and bad.lap is null
    group by 1, 2"""


def ak_stints(T):
    return f"""
    with l as ({_laps(T)}),
    p as (select raceid::int race_id, driverid::int driver_id, lap::int lap from {T}.pit_stops),
    ls as (
      select l.race_id, l.driver_id, l.lap, l.ms, 1 + count(p.lap) stint_number
      from l left join p on p.race_id = l.race_id and p.driver_id = l.driver_id and p.lap < l.lap
      where l.race_id in (select race_id from p)
      group by 1, 2, 3, 4)
    select race_id, driver_id, stint_number, min(lap) start_lap, max(lap) end_lap, count(*) stint_laps,
      avg(ms) avg_lap_time_ms
    from ls group by 1, 2, 3"""


def ak_alt_points(T):
    pts = "decode(po, 1, 25, 2, 18, 3, 15, 4, 12, 5, 10, 6, 8, 7, 6, 8, 4, 9, 2, 10, 1, 0)"
    counts = ", ".join(f"count_if(fp is not null and po = {k}) c{k}" for k in range(1, 11))
    order = ", ".join(f"c{k} desc" for k in range(1, 11))
    return f"""
    with r as (
      select ra.year::int season, x.driverid::int driver_id, x.positionorder::int po, {pos('x.position')} fp
      from {T}.results x join {T}.races ra on ra.raceid = x.raceid),
    s as (select season, driver_id, sum(iff(fp is not null, {pts}, 0)) alt_points, {counts} from r group by 1, 2)
    select season, driver_id, alt_points,
      row_number() over (partition by season order by alt_points desc, {order}, driver_id) alt_position
    from s"""


# column type tags: n=numeric (±0.01), r=rounded numeric (±1, for ms averages/medians),
#                   c=count (null==0), s=string, b=boolean, d=date
DIM_BASE = {"driver_ref": "s", "nationality": "s", "date_of_birth": "d", "career_starts": "c",
            "career_wins": "c", "career_podiums": "c", "world_championships": "c"}

CHECKS = {
    "fct_results": dict(sql=ak_fct_results, keys=["result_id"], cols={
        "race_id": "n", "season": "n", "round": "n", "race_date": "d", "driver_id": "n",
        "constructor_id": "n", "constructor_name": "s", "grid": "n", "finish_position": "n",
        "position_order": "n", "points": "n", "laps": "n", "status": "s", "is_win": "b",
        "is_podium": "b", "fastest_lap_time_ms": "n"}),
    "dim_drivers": dict(sql=ak_dim_drivers, keys=["driver_id"], cols={**DIM_BASE, "full_name": "s"}),
    "mart_driver_season_standings": dict(sql=ak_season_standings, keys=["season", "driver_id"], cols={
        "championship_position": "n", "points": "n", "wins": "c"}),
    "mart_constructor_season_pit_stops": dict(sql=ak_pit_stops, keys=["season", "constructor_id"], cols={
        "pit_stop_count": "n", "median_pit_stop_seconds": "n"}),
    "fct_lap_times": dict(sql=ak_lap_times, keys=["race_id", "driver_id", "lap"], cols={
        "season": "n", "round": "n", "position": "n", "lap_time_ms": "n"}),
    "fct_session_results": dict(sql=ak_session_results, keys=["session_type", "source_result_id"], cols={
        "race_id": "n", "season": "n", "round": "n", "driver_id": "n", "constructor_id": "n",
        "finish_position": "n", "points": "n"}),
    "mart_driver_standings_by_round": dict(sql=ak_standings_by_round, keys=["season", "round", "driver_id"], cols={
        "race_id": "n", "championship_position": "n", "points": "n", "wins": "c"}),
    "fct_qualifying": dict(sql=ak_qualifying, keys=["qualify_id"], cols={
        "race_id": "n", "driver_id": "n", "constructor_id": "n", "q1_ms": "n", "q2_ms": "n", "q3_ms": "n",
        "best_time_ms": "n", "gap_to_pole_ms": "n", "gap_to_pole_pct": "n"}),
    "mart_teammate_head_to_head": dict(sql=ak_teammates, keys=["season", "constructor_id", "driver_id", "teammate_id"],
        cols={"races_together": "c", "races_ahead": "c", "qualifying_together": "c", "qualifying_ahead": "c"}),
    "fct_driver_race_pace": dict(sql=ak_race_pace, keys=["race_id", "driver_id"], cols={
        "green_laps": "n", "median_green_lap_ms": "r"}),
    "fct_stints": dict(sql=ak_stints, keys=["race_id", "driver_id", "stint_number"], cols={
        "start_lap": "n", "end_lap": "n", "stint_laps": "n", "avg_lap_time_ms": "r"}),
    "mart_alt_points_standings": dict(sql=ak_alt_points, keys=["season", "driver_id"], cols={
        "alt_points": "n", "alt_position": "n"}),
    "dim_driver_crosswalk": dict(sql=vx.ak_driver_crosswalk, keys=["driver_key"], cols={"driver_id": "n"}),
    "dim_session_crosswalk": dict(sql=vx.ak_session_crosswalk, keys=["session_key"], cols={
        "race_id": "n", "session_type": "s"}),
    "mart_vendor_result_discrepancies": dict(sql=vx.ak_discrepancies,
        keys=["race_id", "session_type", "driver_id", "discrepancy_type"], cols={}),
    "mart_lap_telemetry_summary": dict(sql=vx.ak_lap_telemetry, keys=["race_id", "driver_id", "lap"], cols={
        "samples": "n", "max_speed_kph": "n", "avg_throttle_pct": "n", "full_throttle_pct": "n",
        "brake_samples": "c"}),
}

# which data checks apply after each task (cumulative, so regressions show up)
PLAN = {
    1: ["fct_results", "dim_drivers", "mart_driver_season_standings", "mart_constructor_season_pit_stops"],
    2: ["fct_lap_times"],
    3: [],
    4: ["fct_session_results", "mart_driver_standings_by_round"],
    5: [], 6: [], 7: [],
}
PLAN_V2 = {
    1: PLAN[1] + ["fct_qualifying", "mart_teammate_head_to_head", "fct_driver_race_pace"],
    2: ["fct_lap_times", "fct_stints"],
    3: [],
    4: PLAN[4] + ["mart_alt_points_standings"],
    5: [], 6: [], 7: [], 8: [],
    9: ["dim_driver_crosswalk", "dim_session_crosswalk", "mart_vendor_result_discrepancies"],
    10: ["mart_lap_telemetry_summary"],
    11: [], 12: [],
}
V2_METRICS = {"race_starts": None, "wins": None, "podiums": None, "championship_points": None,
              "podium_rate": "ratio", "points_per_start": "ratio"}


def suite_of(run_id):
    return "v2" if "_v2_" in run_id.lower() else "v1"


def dim_cols(task):
    cols = {**DIM_BASE}
    if task >= 3:
        cols["current_number"] = "n"
    if task >= 4:
        cols["career_sprint_wins"] = "c"
    if task < 7:
        cols["full_name"] = "s"
    else:
        cols.update(first_name="s", last_name="s")  # v2 is latest
    return cols


def norm(expr, tag):
    if tag in ("n", "r"):
        return f"try_to_double({expr}::varchar)"
    if tag == "c":
        return f"coalesce(try_to_double({expr}::varchar), 0)"
    if tag == "s":
        return f"trim({expr}::varchar)"
    if tag == "b":
        return (f"case when lower({expr}::varchar) in ('true','1','t','y','yes') then 1 "
                f"when lower({expr}::varchar) in ('false','0','f','n','no') then 0 end")
    if tag == "d":
        return f"try_to_date(left({expr}::varchar, 10))"
    raise ValueError(tag)


def neq(a, b, tag):
    if tag in ("n", "c", "r"):
        tol = 1.0 if tag == "r" else 0.01
        return f"not (({a} is null and {b} is null) or abs({a} - {b}) <= {tol})"
    return f"not equal_null({a}, {b})"


# Accepted alternate answers where the prompt is ambiguous or the source is inconsistent:
#   career_podiums: per result row (official stats; 1955 Argentine GP shared drives count twice)
#                   or per distinct race
#   nationality:    raw value, or 'Argentinian ' normalized to 'Argentine' like the other 24 drivers
ALTS = {"dim_drivers": {"career_podiums": "c", "nationality": "s"}}


def compare(conn, relation, answer_sql, keys, cols, alts=None, exclude=None):
    have = {r[0].lower() for r in run(conn, f"select column_name from {db_of(relation)}.information_schema.columns "
                                             f"where table_schema = '{schema_of(relation)}' and table_name = '{table_of(relation)}'")}
    missing_cols = [c for c in keys + list(cols) if c not in have]
    usable = {c: t for c, t in cols.items() if c in have}
    if any(k not in have for k in keys):
        return {"relation": relation, "ok": False, "error": "missing key columns", "missing_columns": missing_cols}
    knorm = lambda alias: ", ".join(f"{norm(f'{alias}.{k}', 's')} k_{k}" for k in keys)
    alts = {c: t for c, t in (alts or {}).items() if c in usable}
    a_sel = ", ".join([knorm("a")] + [f"{norm(f'a.{c}', t)} {c}" for c, t in usable.items()]
                      + [f"{norm(f'a.{c}__alt', t)} {c}__alt" for c, t in alts.items()])
    b_sel = ", ".join([knorm("b")] + [f"{norm(f'b.{c}', t)} {c}" for c, t in usable.items()])
    on = " and ".join(f"e.k_{k} = g.k_{k}" for k in keys)
    mism = ", ".join(f"count_if(e.k_{keys[0]} is not null and g.k_{keys[0]} is not null and "
                     f"{neq(f'e.{c}', f'g.{c}', t)}"
                     + (f" and {neq(f'e.{c}__alt', f'g.{c}', t)}" if c in alts else "")
                     + f") mm_{c}" for c, t in usable.items()) or "0 mm_none"
    sql = f"""
    with e as (select {a_sel} from ({answer_sql}) a),
         g as (select {b_sel} from {relation} b {('where ' + exclude) if exclude else ''}),
         dup as (select count(*) - count(distinct {', '.join('k_' + k for k in keys)}) n from g)
    select (select count(*) from e) expected_rows, (select count(*) from g) actual_rows,
      (select n from dup) duplicate_keys,
      count_if(g.k_{keys[0]} is null) missing_rows, count_if(e.k_{keys[0]} is null) extra_rows, {mism}
    from e full outer join g on {on}"""
    cur = conn.cursor()
    cur.execute(sql)
    row = cur.fetchone()
    names = [d[0].lower() for d in cur.description]
    res = dict(zip(names, row))
    mismatches = {k[3:]: v for k, v in res.items() if k.startswith("mm_") and v}
    ok = (not missing_cols and res["duplicate_keys"] == 0 and res["missing_rows"] == 0
          and res["extra_rows"] == 0 and not mismatches)
    return {"relation": relation, "ok": ok, "missing_columns": missing_cols, "expected_rows": res["expected_rows"],
            "actual_rows": res["actual_rows"], "duplicate_keys": res["duplicate_keys"],
            "missing_rows": res["missing_rows"], "extra_rows": res["extra_rows"], "column_mismatches": mismatches}


def _parts(rel):
    return [p.strip('"') for p in rel.split(".")]


def db_of(rel): return _parts(rel)[0]
def schema_of(rel): return _parts(rel)[1].upper()
def table_of(rel): return _parts(rel)[2].upper()


# ---------- manifest helpers ----------

def load_manifest(proj):
    p = proj / "manifest.json" if (proj / "manifest.json").exists() and proj.name == "prod-artifacts" else proj / "target" / "manifest.json"
    return json.loads(p.read_text()) if p.exists() else None


def find_node(manifest, name, resource_type="model", version=None):
    cands = [n for n in manifest.get("nodes", {}).values()
             if n.get("resource_type") == resource_type and n.get("name") == name]
    if not cands:
        return None
    if version is not None:
        cands = [n for n in cands if str(n.get("version")) == str(version)] or cands
    elif len(cands) > 1:
        latest = cands[0].get("latest_version")
        cands = [n for n in cands if str(n.get("version")) == str(latest)] or cands
    return cands[0]


def ancestors(manifest, uid, seen=None):
    seen = seen if seen is not None else set()
    node = manifest["nodes"].get(uid) or {}
    for parent in node.get("depends_on", {}).get("nodes", []):
        if parent not in seen:
            seen.add(parent)
            ancestors(manifest, parent, seen)
    return seen


def structural(conn, manifest, task, s, suite="v1"):
    out = {}
    if manifest is None:
        return {"manifest": "missing"}
    srcs = [n for n in manifest.get("sources", {}).values()]
    out["sources_point_at_raw_schema"] = bool(srcs) and all(n.get("schema", "").upper() == s["raw"] for n in srcs)
    out["counts"] = {
        "models": sum(1 for n in manifest["nodes"].values() if n["resource_type"] == "model"),
        "data_tests": sum(1 for n in manifest["nodes"].values() if n["resource_type"] == "test"),
        "unit_tests": len(manifest.get("unit_tests", {})),
        "snapshots": sum(1 for n in manifest["nodes"].values() if n["resource_type"] == "snapshot"),
        "seeds": sum(1 for n in manifest["nodes"].values() if n["resource_type"] == "seed"),
        "macros_in_project": sum(1 for m in manifest.get("macros", {}).values()
                                 if m.get("package_name") == manifest.get("metadata", {}).get("project_name")),
        "documented_models": sum(1 for n in manifest["nodes"].values()
                                 if n["resource_type"] == "model" and n.get("description")),
    }
    if task >= 2:
        n = find_node(manifest, "fct_lap_times")
        out["fct_lap_times_incremental"] = bool(n) and n["config"].get("materialized") == "incremental"
        out["fct_lap_times_unique_key"] = n["config"].get("unique_key") if n else None
    if task >= 3:
        snap = find_node(manifest, "snp_drivers", "snapshot")
        out["snapshot_exists"] = bool(snap)
        if snap:
            rel = snap.get("relation_name")
            cols = {r[0].lower() for r in run(conn, f"select column_name from {db_of(rel)}.information_schema.columns "
                                                     f"where table_schema='{schema_of(rel)}' and table_name='{table_of(rel)}'")}
            idc = next((c for c in ("driverid", "driver_id") if c in cols), None)
            ref = next((c for c in ("driverref", "driver_ref") if c in cols), None)
            if idc and ref:
                r = run(conn, f"select count(*), count_if(dbt_valid_to is null) from {rel} "
                              f"where {idc} in (select {idc} from {rel} where {ref} = 'max_verstappen')")
                out["snapshot_verstappen_versions"], out["snapshot_verstappen_current"] = r[0]
    if task >= 4:
        season = find_node(manifest, "mart_driver_season_standings")
        by_round = find_node(manifest, "mart_driver_standings_by_round")
        out["season_standings_derived_from_by_round"] = bool(season and by_round) and \
            by_round["unique_id"] in ancestors(manifest, season["unique_id"])
    if task >= 6:
        tests = [n for n in manifest["nodes"].values() if n["resource_type"] == "test"]

        def guards_constructors(t):
            deps = " ".join(t.get("depends_on", {}).get("nodes", []))
            kind = (t.get("test_metadata") or {}).get("name", "") + " " + t.get("name", "")
            return "constructor" in deps and "unique" in kind and "fct_" not in deps
        out["upstream_constructor_uniqueness_test"] = any(guards_constructors(t) for t in tests)
    if suite == "v2":
        out.update(structural_v2(conn, manifest, task))
    if task >= 7:
        fct = find_node(manifest, "fct_results")
        out["fct_results_contract"] = bool(fct) and fct["config"].get("contract", {}).get("enforced", False)
        versions = [n for n in manifest["nodes"].values() if n["resource_type"] == "model" and n["name"] == "dim_drivers"]
        out["dim_drivers_versions"] = sorted(str(n.get("version")) for n in versions)
        out["dim_drivers_latest_version"] = versions[0].get("latest_version") if versions else None
        out["dim_drivers_contracts"] = all(n["config"].get("contract", {}).get("enforced") for n in versions) if versions else False
        v1 = find_node(manifest, "dim_drivers", version=1)
        out["dim_drivers_v1_deprecation"] = str(v1.get("deprecation_date")) if v1 else None
        uts = list(manifest.get("unit_tests", {}).values())
        out["unit_tests"] = [u.get("name") for u in uts]
    return out


def structural_v2(conn, manifest, task):
    out = {}
    nodes = manifest["nodes"].values()
    tests = [n for n in nodes if n["resource_type"] == "test"]

    def has_row(model, col, value):
        n = find_node(manifest, model)
        if not n:
            return None
        try:
            return run(conn, f"select count(*) from {n['relation_name']} where {col}::varchar = '{value}'")[0][0] > 0
        except Exception:
            return None
    if task >= 2:
        n = find_node(manifest, "fct_stints")
        out["fct_stints_materialized"] = n["config"].get("materialized") if n else None
    if task >= 3:
        out["orphan_result_in_fct_results"] = has_row("fct_results", "result_id", "99001")
        out["orphan_driver_in_dim_drivers"] = has_row("dim_drivers", "driver_id", "9001")
    if task >= 4:
        out["seeds"] = sorted(n["name"] for n in nodes if n["resource_type"] == "seed")
    if task >= 6:
        def guards(t, word):
            deps = " ".join(t.get("depends_on", {}).get("nodes", []))
            kind = (t.get("test_metadata") or {}).get("name", "") + " " + t.get("name", "")
            return word in deps and "unique" in kind and "fct_" not in deps and "mart_" not in deps
        out["upstream_standings_uniqueness_test"] = any(guards(t, "standings") for t in tests)
    if task >= 7:
        for m in ("fct_results", "dim_drivers"):
            n = find_node(manifest, m)
            out[f"{m}_access"] = n.get("access") if n else None
            out[f"{m}_group"] = (n.get("group") or n["config"].get("group")) if n else None
        out["other_public_models"] = sorted(n["name"] for n in nodes if n["resource_type"] == "model"
                                            and n.get("access") == "public" and n["name"] not in ("fct_results", "dim_drivers"))
        out["groups"] = sorted((manifest.get("groups") or {}).keys())
    if task >= 8:
        metrics = {m["name"]: m.get("type") for m in (manifest.get("metrics") or {}).values()}
        out["semantic_models"] = sorted(m["name"] for m in (manifest.get("semantic_models") or {}).values())
        out["metrics"] = metrics
        out["missing_metrics"] = [m for m in V2_METRICS if m not in metrics]
        out["wrong_metric_types"] = [m for m, t in V2_METRICS.items() if t and m in metrics and metrics[m] != t]
        out["time_spine"] = any("time_spine" in json.dumps(n.get("config", {})) or "time_spine" in n["name"]
                                for n in nodes if n["resource_type"] == "model") or bool(manifest.get("time_spine"))
    if task >= 9:
        out["seeds"] = sorted(n["name"] for n in nodes if n["resource_type"] == "seed")
    if task >= 10:
        for m in ("fct_telemetry", "mart_lap_telemetry_summary"):
            n = find_node(manifest, m)
            out[f"{m}_config"] = {k: n["config"].get(k) for k in
                                  ("materialized", "incremental_strategy", "unique_key", "event_time",
                                   "lookback", "cluster_by")} if n else None
    return out


def telemetry_cost(conn, s, start_ts, end_ts=None):
    """Bytes this run's queries scanned while touching telemetry during the harness rebuild,
    versus the raw table's size. Matches on the run's own schemas, so staging views over the raw
    table count too and other concurrent runs don't."""
    raw, target = s["raw"], s["target"]
    end = f", end_time_range_end => to_timestamp_ltz({end_ts})" if end_ts else ""
    scanned, queries = run(conn, f"""
        select coalesce(sum(bytes_scanned), 0), count(*)
        from table(information_schema.query_history_by_user(
          user_name => current_user(), end_time_range_start => to_timestamp_ltz({start_ts}){end},
          result_limit => 10000))
        where query_text ilike '%telemetry%'
          and (query_text ilike '%{raw}.%' or query_text ilike '%{target}%')
          and query_type in ('SELECT', 'INSERT', 'MERGE', 'CREATE_TABLE_AS_SELECT', 'DELETE', 'UPDATE')""")[0]
    size = run(conn, f"select bytes from information_schema.tables where table_schema = '{raw}' "
                     f"and table_name = 'CAR_TELEMETRY'")[0][0]
    return {"bytes_scanned": scanned, "queries": queries, "raw_table_bytes": size,
            "scan_ratio": round(scanned / size, 3) if size else None}


def ci_probe(proj: Path, manifest, gdir: Path, conn=None, s=None):
    """Touch one mid-DAG model, run the agent's CI script, then check the warehouse: which
    relations in the run's CI schemas were (re)built during the probe, versus the edited model
    plus its downstream models. Reading the warehouse (not run_results.json) works whatever
    target path or follow-up commands the script uses."""
    out = {"ci_script": (proj / "scripts" / "ci.sh").exists(),
           "prod_artifacts": (proj / "prod-artifacts" / "manifest.json").exists()}
    probe = find_node(manifest, "mart_driver_standings_by_round") if manifest else None
    if not (out["ci_script"] and probe):
        return {**out, "ok": False, "error": "missing ci script or probe model"}
    nodes, children = manifest["nodes"], manifest.get("child_map", {})
    expected, stack = {probe["unique_id"]}, [probe["unique_id"]]
    while stack:
        for c in children.get(stack.pop(), []):
            if c.startswith("model.") and c not in expected:
                expected.add(c)
                stack.append(c)
    # Models that don't exist in prod yet are state:modified too, so they (and their children) belong in CI.
    prod_m = load_manifest(proj / "prod-artifacts") if out["prod_artifacts"] else None
    if prod_m:
        new_nodes = [u for u, n in nodes.items() if n.get("resource_type") == "model" and u not in prod_m.get("nodes", {})]
        stack = list(new_nodes)
        expected.update(new_nodes)
        while stack:
            for c in children.get(stack.pop(), []):
                if c.startswith("model.") and c not in expected:
                    expected.add(c)
                    stack.append(c)
    expected_rel = {table_of(nodes[u]["relation_name"]).lower() for u in expected if nodes.get(u, {}).get("relation_name")}
    # dbt v2 also maintains an unversioned relation for a versioned model's latest version
    expected_rel |= {nodes[u]["name"].lower() for u in expected if nodes.get(u, {}).get("version") is not None}
    path = proj / probe["original_file_path"]
    original = path.read_text()
    path.write_text(original.rstrip("\n") + "\n-- ci probe\n")
    ci_like = s["target"].upper() + "_CI"
    t0 = run(conn, "select current_timestamp()")[0][0]
    try:
        p = subprocess.run(["bash", "scripts/ci.sh"], cwd=proj, capture_output=True, text=True, timeout=3600)
        (gdir / "t11_ci_probe.log").write_text(p.stdout + "\n--- stderr ---\n" + p.stderr)
        rows = run(conn, f"""select table_schema, table_name from information_schema.tables
                             where table_schema ilike '{ci_like}%%' and last_altered >= %s""", (t0,))
        built = {r[1].lower() for r in rows}
        out.update(ci_exit=p.returncode, expected=sorted(expected_rel), built=sorted(built),
                   extra=sorted(built - expected_rel), missing=sorted(expected_rel - built),
                   ci_schemas=sorted({r[0] for r in rows}))
        out["built_into_ci_schema"] = bool(rows)
        out["ok"] = p.returncode == 0 and not out["missing"] and not out["extra"]
    finally:
        path.write_text(original)
    return out


def dbt_build(proj: Path, log: Path):
    t0 = time.time()
    p = subprocess.run(["dbt", "build", "--profiles-dir", str(proj)], cwd=proj, capture_output=True, text=True)
    log.write_text(p.stdout + "\n--- stderr ---\n" + p.stderr)
    return {"exit_code": p.returncode, "seconds": round(time.time() - t0, 1), "log": str(log)}


def main():
    run_id, task, phase = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    do_build = "--build" in sys.argv
    proj = Path(CFG["RUNS_DIR"]) / run_id / "project"
    gdir = ROOT / "results" / run_id / "grades"
    gdir.mkdir(parents=True, exist_ok=True)
    s = run_schemas(run_id)
    conn = connect()
    suite = suite_of(run_id)
    plan = PLAN_V2 if suite == "v2" else PLAN
    result = {"run_id": run_id, "task": task, "phase": phase, "suite": suite}
    # v2: a result for driver 9001 exists before the driver record does. Until it arrives, the
    # placeholder row the agent should have isn't in the answer key, so leave it out of the comparison.
    orphan_pending = suite == "v2" and task >= 3 and run(conn, f"""
        select (select count(*) from {s['truth']}.results where resultid = '99001') > 0
           and (select count(*) from {s['truth']}.drivers where driverid = '9001') = 0""")[0][0]
    dim_exclude = "b.driver_id::varchar <> '9001'" if orphan_pending else None
    if suite == "v2" and task == 11 and do_build:
        result["ci_probe"] = ci_probe(proj, load_manifest(proj), gdir, conn, s)
    build_start = run(conn, "select date_part(epoch_second, current_timestamp())")[0][0]
    if do_build:
        result["harness_build"] = dbt_build(proj, gdir / f"t{task:02d}_{phase}_build.log")
        if suite == "v2" and task >= 10:
            time.sleep(5)  # let query history catch up
            result["telemetry_cost"] = telemetry_cost(conn, s, build_start)
    manifest = load_manifest(proj)
    result["structural"] = structural(conn, manifest, task, s, suite)

    checks = {}
    models = [m for t in range(1, task + 1) for m in plan[t]]
    for m in models:
        spec = CHECKS[m]
        cols = dim_cols(task) if m == "dim_drivers" else spec["cols"]
        node = find_node(manifest, m) if manifest else None
        if not node:
            checks[m] = {"ok": False, "error": "model not in manifest"}
            continue
        version = 2 if (m == "dim_drivers" and task >= 7) else 1
        answer = spec["sql"](s["truth"], version) if m == "dim_drivers" else spec["sql"](s["truth"])
        try:
            checks[m] = compare(conn, node["relation_name"], answer, spec["keys"], cols, ALTS.get(m),
                                dim_exclude if m == "dim_drivers" else None)
        except Exception as e:  # relation missing, type errors, and so on
            checks[m] = {"ok": False, "relation": node.get("relation_name"), "error": str(e)[:500]}
    if task >= 7 and manifest:
        v1 = find_node(manifest, "dim_drivers", version=1)
        if v1:
            try:
                checks["dim_drivers_v1"] = compare(conn, v1["relation_name"], ak_dim_drivers(s["truth"], 1),
                                                   ["driver_id"], {**dim_cols(6)}, ALTS["dim_drivers"], dim_exclude)
            except Exception as e:
                checks["dim_drivers_v1"] = {"ok": False, "error": str(e)[:500]}
    result["data_checks"] = checks
    result["data_score"] = f"{sum(1 for c in checks.values() if c.get('ok'))}/{len(checks)}"
    out = gdir / f"t{task:02d}_{phase}.json"
    if not do_build and out.exists():  # regrade: keep the earlier harness build result
        prev = json.loads(out.read_text())
        if "harness_build" in prev:
            result["harness_build"] = prev["harness_build"]
    out.write_text(json.dumps(result, indent=2, default=str))
    print(f"[grade] {run_id} t{task} {phase}: data {result['data_score']}"
          + (f", harness build exit {result['harness_build']['exit_code']}" if do_build else ""))


if __name__ == "__main__":
    main()
