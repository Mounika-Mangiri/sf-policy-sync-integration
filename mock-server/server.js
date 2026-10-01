// Mock policy-administration API for local demos and contract tests.
// No dependencies: Node's built-in http module only. All data is synthetic.
"use strict";

const http = require("node:http");
const policies = require("./policies.json");

const API_KEY = process.env.MOCK_API_KEY || "local-dev-only";

function send(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

function handler(req, res) {
  const started = Date.now();
  res.on("finish", () => {
    console.log(
      JSON.stringify({ method: req.method, url: req.url, status: res.statusCode, ms: Date.now() - started })
    );
  });

  if (req.headers["x-api-key"] !== API_KEY) {
    return send(res, 401, { error: "Missing or invalid x-api-key" });
  }
  const match = /^\/policies\/([A-Za-z0-9-]{1,40})$/.exec(req.url || "");
  if (req.method !== "GET" || !match) {
    return send(res, 404, { error: "Not found" });
  }
  const policyNumber = decodeURIComponent(match[1]);
  if (policyNumber.startsWith("DEMO-DOWN-")) {
    return send(res, 503, { error: "Service unavailable" });
  }
  if (policyNumber.startsWith("DEMO-THROTTLE-")) {
    res.setHeader("Retry-After", "60");
    return send(res, 429, { error: "Too many requests" });
  }
  const policy = policies.find((p) => p.policyNumber === policyNumber);
  if (!policy) {
    return send(res, 404, { error: "Policy not found" });
  }
  return send(res, 200, policy);
}

function createServer() {
  return http.createServer(handler);
}

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  createServer().listen(port, () => console.log(`Mock policy API on http://localhost:${port}`));
}

module.exports = { createServer };
