const http = require('http');
const PORT = 3001;

// Realistic dataset: some users are fully qualified, some aren't
const TRAINING_DB = {
  'jdoe':    ['SAFETY-101', 'ASSET-201', 'PLANNER-301'],           // qualified for Engineer + Planner
  'mwebb':   ['SAFETY-101', 'ASSET-201'],                           // qualified for Engineer only
  'psharma': [],                                                    // not qualified for anything
  'lortega': ['SAFETY-101', 'SAFETY-201', 'SUPERVISOR-401', 'ASSET-201'], // qualified for Supervisor + Engineer
  'akhan':   ['SAFETY-101'],                                        // qualified for Viewer only
};

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const m = req.url.match(/^\/api\/training\/([^\/]+)\/completed$/);
  if (m && req.method === 'GET') {
    const userId = m[1];
    const modules = TRAINING_DB[userId] || [];
    console.log(`[LMS] ${userId} → ${JSON.stringify(modules)}`);
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify({ userId, completedModules: modules, lastUpdated: new Date().toISOString() }));
  }
  if (req.url === '/api/training' && req.method === 'GET') {
    // admin view — lists all
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify(TRAINING_DB));
  }
  res.writeHead(404); res.end('Not found');
});

server.listen(PORT, () => console.log(`Training LMS mock listening on :${PORT}`));
