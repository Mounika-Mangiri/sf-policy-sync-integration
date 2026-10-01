"use strict";
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { createServer } = require("../server");

let server;
let base;
const KEY = { "x-api-key": "local-dev-only" };

before(async () => {
  server = createServer();
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test("returns a policy matching the PolicyDto contract", async () => {
  const res = await fetch(`${base}/policies/DEMO-OK-1`, { headers: KEY });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(Object.keys(body).sort(), ["paidToDate", "policyNumber", "premiumAmount", "status"]);
  assert.match(body.paidToDate, /^\d{4}-\d{2}-\d{2}$/);
});

test("rejects requests without the API key", async () => {
  const res = await fetch(`${base}/policies/DEMO-OK-1`);
  assert.equal(res.status, 401);
});

test("unknown policy returns 404", async () => {
  const res = await fetch(`${base}/policies/NOPE-1`, { headers: KEY });
  assert.equal(res.status, 404);
});

test("DEMO-DOWN-* simulates an outage with 503", async () => {
  const res = await fetch(`${base}/policies/DEMO-DOWN-1`, { headers: KEY });
  assert.equal(res.status, 503);
});

test("DEMO-THROTTLE-* returns 429 with Retry-After", async () => {
  const res = await fetch(`${base}/policies/DEMO-THROTTLE-1`, { headers: KEY });
  assert.equal(res.status, 429);
  assert.equal(res.headers.get("retry-after"), "60");
});

test("rejects path traversal and odd characters", async () => {
  const res = await fetch(`${base}/policies/..%2Fetc`, { headers: KEY });
  assert.equal(res.status, 404);
});
