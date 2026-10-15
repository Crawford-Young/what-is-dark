// DEBUG PROBE — remove before gates (issue #14): reads a surf-lab seam_contact_*.csv
// and lists each hard stop with its contact normals, then checks whether the stop's
// contacts sit on a facet boundary (a multiple of the run's FILLET_STEP along the arc).
// Boundary distance is RECOMPUTED here from s_in_arc and the step; the probe's own
// boundary_dist column is not trusted. Control: the chance a random in-arc contact
// lands within tol of a boundary is 2*tol/step, reported next to the observed rates.
//
// Usage: node scripts/dev/seam_contact_stops.mjs [csv] [--tol=0.02]
//   no csv -> newest seam_contact_*.csv in Godot's user://probe for this project.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const DEFAULT_TOL = 0.02; // m; an edge contact sits ON the boundary line, so float noise only
const EDGE_DEV_DEG = 0.5; // contact normal this far off its facet's normal reads as an edge/vertex hit

function num(v) {
  return v === undefined || v === "" ? NaN : Number(v);
}

function boundaryInfo(sInArc, facetK, step, tol) {
  if (!(facetK >= 0) || !Number.isFinite(sInArc) || !(step > 0)) {
    return { boundaryDist: NaN, onBoundary: false };
  }
  const boundaryDist = Math.abs(sInArc - Math.round(sInArc / step) * step);
  return { boundaryDist, onBoundary: boundaryDist <= tol };
}

export function analyze(text, { tol = DEFAULT_TOL } = {}) {
  const cols = {};
  const meta = {};
  const ticks = [];
  const contactsByKey = new Map();
  for (const raw of text.split(/\r?\n/)) {
    if (!raw) continue;
    const f = raw.split(",");
    if (f[0] === "PROBE-META") {
      for (const kv of f.slice(1)) {
        const [k, v] = kv.split("=");
        meta[k] = v;
      }
    } else if (f[0] === "PROBE-COLS") {
      cols[f[1]] = f.slice(2);
    } else if ((f[0] === "TICK" || f[0] === "CONTACT") && cols[f[0]]) {
      const rec = Object.fromEntries(cols[f[0]].map((c, i) => [c, f[i + 1]]));
      if (f[0] === "TICK") {
        ticks.push(rec);
      } else {
        const key = `${rec.run}:${rec.tick}`;
        if (!contactsByKey.has(key)) contactsByKey.set(key, []);
        contactsByKey.get(key).push(rec);
      }
    }
  }

  const stops = [];
  const byStep = new Map();
  const bucket = (step) => {
    if (!byStep.has(step)) {
      byStep.set(step, {
        stops: 0,
        stopsOnBoundary: 0,
        surfContacts: 0,
        surfContactsOnBoundary: 0,
        chanceRate: Math.min(1, (2 * tol) / step),
      });
    }
    return byStep.get(step);
  };

  for (const t of ticks) {
    const step = num(t.step);
    const b = bucket(step);
    const contacts = (contactsByKey.get(`${t.run}:${t.tick}`) ?? []).map((c) => {
      const surf = !String(c.surface).startsWith("other:");
      const info = surf
        ? boundaryInfo(num(c.s_in_arc), num(c.facet_k), step, tol)
        : { boundaryDist: NaN, onBoundary: false };
      if (surf && num(c.facet_k) >= 0) {
        b.surfContacts += 1;
        if (info.onBoundary) b.surfContactsOnBoundary += 1;
      }
      return {
        surface: c.surface,
        normal: [num(c.nx), num(c.ny), num(c.nz)],
        faceSeg: num(c.face_seg),
        devDeg: num(c.dev_deg),
        seam: num(c.seam),
        sInArc: num(c.s_in_arc),
        facetK: num(c.facet_k),
        ...info,
      };
    });
    if (t.hard_stop !== "1") continue;
    const onBoundary = contacts.some((c) => c.onBoundary);
    b.stops += 1;
    if (onBoundary) b.stopsOnBoundary += 1;
    stops.push({
      run: num(t.run),
      tick: num(t.tick),
      station: t.station,
      step,
      vPre: num(t.v_pre),
      vSlide: num(t.v_slide),
      vPost: num(t.v_post),
      tickRatio: num(t.tick_ratio),
      clipped: t.clipped === "1",
      onFloor: t.on_floor === "1",
      sInArc: num(t.s_in_arc),
      contacts,
      onBoundary,
    });
  }
  return { meta, tol, ticks: ticks.length, stops, byStep };
}

const f3 = (x) => (Number.isFinite(x) ? x.toFixed(3) : "-");

export function formatReport(r) {
  const out = [];
  out.push(
    `engine ${r.meta.engine ?? "?"}  godot ${r.meta.godot ?? "?"}  tick rows ${r.ticks}  hard stops ${r.stops.length}  tol ${r.tol} m`,
  );
  for (const s of r.stops) {
    out.push(
      `run ${s.run} tick ${s.tick} ${s.station} step ${s.step}  v ${f3(s.vPre)} -> slide ${f3(s.vSlide)} -> ${f3(s.vPost)} (x${f3(s.tickRatio)} vs last step)` +
        `  clipped=${s.clipped} floor=${s.onFloor}  ${s.onBoundary ? "ON facet boundary" : "off boundary"}`,
    );
    if (s.contacts.length === 0) out.push("    (no contacts)");
    for (const c of s.contacts) {
      const edge = c.devDeg > EDGE_DEV_DEG ? "  EDGE-NORMAL" : "";
      out.push(
        `    ${c.surface} n=(${c.normal.map(f3).join(", ")}) face_seg ${Number.isFinite(c.faceSeg) ? c.faceSeg : "-"} dev ${f3(c.devDeg)} deg` +
          `  seam ${Number.isFinite(c.seam) ? c.seam : "-"} s_in_arc ${f3(c.sInArc)} facet ${Number.isFinite(c.facetK) ? c.facetK : "-"}` +
          `  boundary ${f3(c.boundaryDist)} m${c.onBoundary ? " ON" : ""}${edge}`,
      );
    }
  }
  for (const [step, b] of [...r.byStep].sort((a, z) => a[0] - z[0])) {
    const rate = (n, d) => (d ? `${n}/${d} = ${((100 * n) / d).toFixed(1)}%` : "0/0");
    out.push(
      `step ${step}: stops on boundary ${rate(b.stopsOnBoundary, b.stops)}; in-arc surf contacts on boundary ${rate(b.surfContactsOnBoundary, b.surfContacts)}; chance ${(100 * b.chanceRate).toFixed(1)}%`,
    );
  }
  return out.join("\n");
}

function newestCsv() {
  const appdata = process.env.APPDATA ?? join(process.env.HOME ?? "", ".local", "share");
  const dir = join(appdata, "Godot", "app_userdata", "What Is Dark", "probe");
  const files = readdirSync(dir)
    .filter((f) => f.startsWith("seam_contact_") && f.endsWith(".csv"))
    .map((f) => join(dir, f))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  if (files.length === 0) throw new Error(`no seam_contact_*.csv in ${dir}`);
  return files[0];
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const args = process.argv.slice(2);
  const tolArg = args.find((a) => a.startsWith("--tol="));
  const file = args.find((a) => !a.startsWith("--")) ?? newestCsv();
  const tol = tolArg ? Number(tolArg.slice(6)) : DEFAULT_TOL;
  console.log(`file ${file}`);
  console.log(formatReport(analyze(readFileSync(file, "utf8"), { tol })));
}
