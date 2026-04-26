/**
 * Teleport Adapter
 * ----------------
 * Exposes simple REST endpoints that BAMOE calls to provision users
 * and manage Access List membership in Teleport.
 *
 * Behind the scenes, this service shells out to `tctl` using a long-lived
 * identity file mounted from a Kubernetes Secret. In production you'd
 * replace this with a Teleport Machine ID bot (`tbot`) that rotates the
 * service's certificate every hour automatically — same pattern, just
 * with proper ephemeral credentials.
 *
 * This adapter is deliberately thin — it's the kind of integration shim
 * a customer would write themselves when wiring Teleport into a larger
 * automation platform.
 */

const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PORT = 3500;
const IDENTITY_FILE = process.env.TELEPORT_IDENTITY_FILE || '/etc/teleport/identity';
const AUTH_SERVER   = process.env.TELEPORT_AUTH_SERVER   || 'teleport:3025';
const CLUSTER_NAME  = process.env.TELEPORT_CLUSTER_NAME  || 'maximo-demo.localtest.me';

// ── tctl runner ──────────────────────────────────────────────────────────────
function runTctl(args, stdinYaml) {
  return new Promise((resolve, reject) => {
    const fullArgs = [
      '--auth-server', AUTH_SERVER,
      '--identity', IDENTITY_FILE,
      ...args
    ];
    console.log('[tctl]', fullArgs.join(' '));
    const child = spawn('tctl', fullArgs, { stdio: ['pipe', 'pipe', 'pipe'] });

    let stdout = '', stderr = '';
    child.stdout.on('data', d => stdout += d);
    child.stderr.on('data', d => stderr += d);
    child.on('error', reject);
    child.on('close', code => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`tctl exited ${code}: ${stderr.trim() || stdout.trim()}`));
    });

    if (stdinYaml) child.stdin.write(stdinYaml);
    child.stdin.end();
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────
function roleToAccessList(role) {
  switch (role) {
    case 'MAXIMO_ENGINEER':   return 'maximo-engineers';
    case 'MAXIMO_PLANNER':    return 'maximo-planners';
    case 'MAXIMO_SUPERVISOR': return 'maximo-supervisors';
    case 'MAXIMO_VIEWER':     return 'maximo-viewers';
    default: return 'maximo-viewers';
  }
}

async function createUser({ username, email, firstName, lastName }) {
  // Idempotent: if user exists, return it; else create.
  try {
    const out = await runTctl(['get', `user/${username}`, '--format=json']);
    const existing = JSON.parse(out.stdout);
    console.log(`[adapter] user ${username} already exists`);
    return { username, status: 'exists', detail: existing[0]?.metadata };
  } catch (e) {
    // Not found — create
  }

  const userYaml = `
kind: user
version: v2
metadata:
  name: ${username}
  description: "Provisioned by BAMOE on behalf of ${firstName} ${lastName}"
spec:
  roles: ['access']
  traits:
    email: ['${email}']
    logins: ['${username}']
    firstname: ['${firstName}']
    lastname: ['${lastName}']
`.trim();

  await runTctl(['create', '-f'], userYaml);
  console.log(`[adapter] created user ${username}`);
  return { username, status: 'created' };
}

async function addToAccessList({ username, role, requestId, notes }) {
  const listName = roleToAccessList(role);

  const memberYaml = `
kind: access_list_member
version: v1
metadata:
  name: ${username}
spec:
  access_list: ${listName}
  name: ${username}
  joined: '${new Date().toISOString()}'
  added_by: bamoe-service
  reason: "Provisioned via BAMOE workflow ${requestId || ''}: ${notes || ''}"
`.trim();

  await runTctl(['create', '-f', '--force'], memberYaml);
  console.log(`[adapter] added ${username} → ${listName}`);
  return { username, accessList: listName, status: 'added' };
}

async function getAuditEntries(limit = 20) {
  // Recent audit events — Teleport tags every change. Big selling point.
  try {
    const out = await runTctl(['events', 'export', '--types=user.create,access_list.member.create', '--limit=' + limit, '--format=json']);
    const lines = out.stdout.trim().split('\n').filter(Boolean);
    return lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  } catch (e) {
    console.warn('[adapter] audit fetch failed:', e.message);
    return [];
  }
}

// ── HTTP server ──────────────────────────────────────────────────────────────
function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      try { resolve(body ? JSON.parse(body) : {}); }
      catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }

  try {
    if (req.url === '/api/users' && req.method === 'POST') {
      const body = await readBody(req);
      const result = await createUser(body);
      res.writeHead(200, {'Content-Type':'application/json'});
      return res.end(JSON.stringify(result));
    }

    if (req.url === '/api/access-lists/members' && req.method === 'POST') {
      const body = await readBody(req);
      const result = await addToAccessList(body);
      res.writeHead(200, {'Content-Type':'application/json'});
      return res.end(JSON.stringify(result));
    }

    if (req.url.startsWith('/api/audit') && req.method === 'GET') {
      const events = await getAuditEntries(20);
      res.writeHead(200, {'Content-Type':'application/json'});
      return res.end(JSON.stringify({ events }));
    }

    if (req.url === '/health' && req.method === 'GET') {
      res.writeHead(200, {'Content-Type':'application/json'});
      return res.end(JSON.stringify({ status: 'ok' }));
    }

    res.writeHead(404); res.end('Not found');
  } catch (e) {
    console.error('[adapter] error:', e);
    res.writeHead(500, {'Content-Type':'application/json'});
    res.end(JSON.stringify({ error: e.message }));
  }
});

server.listen(PORT, () => {
  console.log(`Teleport adapter listening on :${PORT}`);
  console.log(`  auth_server=${AUTH_SERVER}`);
  console.log(`  identity=${IDENTITY_FILE}`);
});
