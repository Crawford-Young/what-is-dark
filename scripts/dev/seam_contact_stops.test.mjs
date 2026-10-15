// DEBUG PROBE — remove before gates (issue #14): tests for the seam-contact stop analyzer.
// Run: node --test scripts/dev/
import { test } from "node:test";
import assert from "node:assert/strict";
import { analyze, formatReport } from "./seam_contact_stops.mjs";

const TICK_COLS =
  "run,tick,station,step,x,y,z,vx,vy,vz,v_pre,v_slide,v_post,h_post,tick_ratio,step_ratio,slides,contacts,on_floor,clipped,hard_stop,seam,s_from_lip,s_in_arc,facet_k,boundary_dist";
const CONTACT_COLS =
  "run,tick,slide_i,coll_j,surface,shape_idx,nx,ny,nz,px,py,pz,face_index,face_seg,facet_nx,facet_ny,facet_nz,dev_deg,seam,s_from_lip,s_in_arc,facet_k,boundary_dist";

// Builds a row from a column list and a partial record; unnamed columns are 0.
function row(kind, cols, values) {
  return [kind, ...cols.split(",").map((c) => (c in values ? values[c] : 0))].join(",");
}

const FIXTURE = [
  "PROBE-META,engine=GodotPhysics3D,godot=4.7.1-stable,physics_ticks=120,fillet_step=0.250",
  `PROBE-COLS,TICK,${TICK_COLS}`,
  `PROBE-COLS,CONTACT,${CONTACT_COLS}`,
  "PROBE-RUN,1,AR-5°,station,0.250",
  // Moving tick, one face contact mid-facet: not a stop.
  row("TICK", TICK_COLS, { run: 1, tick: 10, station: "AR-5°", step: 0.25, v_post: 20, tick_ratio: 1.0, hard_stop: 0, seam: 1, s_in_arc: 1.125 }),
  row("CONTACT", CONTACT_COLS, { run: 1, tick: 10, surface: "AR-5°", nx: 0.77, ny: 0.616, nz: -0.163, face_seg: 6, dev_deg: 0.0, seam: 1, s_in_arc: 1.125, facet_k: 4 }),
  // Hard stop: one contact sitting ON the 0.25 m boundary at s = 1.75 (7 steps) with an off-face normal.
  row("TICK", TICK_COLS, { run: 1, tick: 11, station: "AR-5°", step: 0.25, v_post: 4, tick_ratio: 0.2, hard_stop: 1, seam: 1, s_in_arc: 1.748 }),
  row("CONTACT", CONTACT_COLS, { run: 1, tick: 11, surface: "AR-5°", nx: 0.1, ny: 0.2, nz: 0.97, face_seg: 9, dev_deg: 62.5, seam: 1, s_in_arc: 1.7505, facet_k: 7 }),
  row("CONTACT", CONTACT_COLS, { run: 1, tick: 11, surface: "AR-5°", nx: 0.77, ny: 0.616, nz: -0.163, face_seg: 8, dev_deg: 0.0, seam: 1, s_in_arc: 1.66, facet_k: 6 }),
  "PROBE-STEP,1,12,1.500",
  "PROBE-RUN,2,AR-5°,station,1.500",
  // Hard stop at the coarse step, contact mid-facet (0.75 m from both 1.5 m edges).
  row("TICK", TICK_COLS, { run: 2, tick: 40, station: "AR-5°", step: 1.5, v_post: 3, tick_ratio: 0.3, hard_stop: 1, seam: 2, s_in_arc: 2.25 }),
  row("CONTACT", CONTACT_COLS, { run: 2, tick: 40, surface: "AR-5°", nx: 0.77, ny: 0.616, nz: -0.163, face_seg: 4, dev_deg: 0.0, seam: 2, s_in_arc: 2.25, facet_k: 1 }),
].join("\n");

test("lists every hard stop with its contacts and the run's step", () => {
  const r = analyze(FIXTURE);
  assert.equal(r.meta.engine, "GodotPhysics3D");
  assert.equal(r.stops.length, 2);
  const [a, b] = r.stops;
  assert.equal(a.run, 1);
  assert.equal(a.tick, 11);
  assert.equal(a.step, 0.25);
  assert.equal(a.contacts.length, 2);
  assert.deepEqual(a.contacts[0].normal, [0.1, 0.2, 0.97]);
  assert.equal(b.step, 1.5);
  assert.equal(b.contacts.length, 1);
});

test("recomputes facet-boundary alignment from s_in_arc and the step", () => {
  const r = analyze(FIXTURE, { tol: 0.02 });
  const [a, b] = r.stops;
  assert.equal(a.onBoundary, true, "1.7505 is 0.0005 from 7 x 0.25");
  assert.ok(Math.abs(a.contacts[0].boundaryDist - 0.0005) < 1e-9);
  assert.equal(a.contacts[1].onBoundary, false, "1.66 is 0.09 from 1.75");
  assert.equal(b.onBoundary, false, "2.25 is mid-facet at 1.5 m");
  assert.ok(Math.abs(b.contacts[0].boundaryDist - 0.75) < 1e-9);
});

test("reports the chance rate of a boundary hit per step as the control", () => {
  const r = analyze(FIXTURE, { tol: 0.02 });
  const fine = r.byStep.get(0.25);
  assert.equal(fine.stops, 1);
  assert.equal(fine.stopsOnBoundary, 1);
  assert.equal(fine.surfContacts, 3);
  assert.equal(fine.surfContactsOnBoundary, 1);
  assert.ok(Math.abs(fine.chanceRate - 0.16) < 1e-9, "2 x 0.02 / 0.25");
  const coarse = r.byStep.get(1.5);
  assert.equal(coarse.stops, 1);
  assert.equal(coarse.stopsOnBoundary, 0);
});

test("ignores contacts outside an arc when judging alignment", () => {
  const text = [
    `PROBE-COLS,TICK,${TICK_COLS}`,
    `PROBE-COLS,CONTACT,${CONTACT_COLS}`,
    row("TICK", TICK_COLS, { run: 1, tick: 5, station: "AR-5°", step: 0.25, v_post: 2, tick_ratio: 0.1, hard_stop: 1 }),
    row("CONTACT", CONTACT_COLS, { run: 1, tick: 5, surface: "AR-5°", s_in_arc: -3.0, facet_k: -1 }),
    row("CONTACT", CONTACT_COLS, { run: 1, tick: 5, surface: "other:StaticBody3D", s_in_arc: "", facet_k: "" }),
  ].join("\n");
  const [s] = analyze(text).stops;
  assert.equal(s.onBoundary, false);
  assert.equal(s.contacts[0].onBoundary, false);
  assert.equal(s.contacts[1].onBoundary, false);
});

test("report names each stop, its normals, and the boundary verdict", () => {
  const out = formatReport(analyze(FIXTURE, { tol: 0.02 }));
  assert.match(out, /engine GodotPhysics3D/);
  assert.match(out, /run 1 tick 11 .*step 0\.25.*ON facet boundary/);
  assert.match(out, /n=\(0\.100, 0\.200, 0\.970\)/);
  assert.match(out, /run 2 tick 40 .*step 1\.5.*off boundary/);
  assert.match(out, /chance/);
});
