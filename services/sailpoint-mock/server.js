const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const BAMOE_URL = process.env.BAMOE_URL || 'http://bamoe-service:8080';

// Seed employee data — in a real system this would come from HR
const EMPLOYEES = [
  { userId: 'jdoe',     firstName: 'Jane',    lastName: 'Doe',     email: 'jane.doe@company.com',    managerEmail: 'mgr.smith@company.com' },
  { userId: 'mwebb',    firstName: 'Marcus',  lastName: 'Webb',    email: 'marcus.webb@company.com', managerEmail: 'mgr.smith@company.com' },
  { userId: 'psharma',  firstName: 'Priya',   lastName: 'Sharma',  email: 'priya.sharma@company.com',managerEmail: 'mgr.jones@company.com' },
  { userId: 'lortega',  firstName: 'Luis',    lastName: 'Ortega',  email: 'luis.ortega@company.com', managerEmail: 'mgr.jones@company.com' },
  { userId: 'akhan',    firstName: 'Aisha',   lastName: 'Khan',    email: 'aisha.khan@company.com',  managerEmail: 'mgr.smith@company.com' },
];

const ROLES = ['MAXIMO_ENGINEER', 'MAXIMO_PLANNER', 'MAXIMO_SUPERVISOR', 'MAXIMO_VIEWER'];

function postToBamoe(payload) {
  return new Promise((resolve, reject) => {
    const url = new URL(BAMOE_URL + '/api/access-requests');
    const data = JSON.stringify(payload);
    const req = http.request({
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': data.length }
    }, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  // Simulated "My Access" UI
  if (req.url === '/' && req.method === 'GET') {
    const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8')
      .replace('{{EMPLOYEES}}', JSON.stringify(EMPLOYEES))
      .replace('{{ROLES}}', JSON.stringify(ROLES));
    res.writeHead(200, {'Content-Type': 'text/html'}); return res.end(html);
  }

  // Event trigger (called from the UI or curl)
  if (req.url === '/api/trigger-approval' && req.method === 'POST') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', async () => {
      try {
        const { userId, role } = JSON.parse(body);
        const employee = EMPLOYEES.find(e => e.userId === userId);
        if (!employee) {
          res.writeHead(404); return res.end(JSON.stringify({ error: 'Unknown employee' }));
        }
        const requestId = 'REQ-' + Date.now().toString().slice(-6);
        const payload = { ...employee, role, requestId, requestDate: new Date().toISOString() };
        console.log('[SailPoint] Access approved, forwarding to BAMOE:', payload);
        const result = await postToBamoe(payload);
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ requestId, bamoe: result }));
      } catch (e) {
        res.writeHead(500); res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // List available employees/roles
  if (req.url === '/api/employees') {
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify(EMPLOYEES));
  }
  if (req.url === '/api/roles') {
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify(ROLES));
  }

  res.writeHead(404); res.end('Not found');
});

server.listen(PORT, () => console.log(`SailPoint mock listening on :${PORT}`));
