const http = require('http');
const PORT = 3003;
const LOG = [];

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  if (req.url === '/api/notify' && req.method === 'POST') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      try {
        const ev = JSON.parse(body);
        ev.timestamp = new Date().toISOString();
        LOG.unshift(ev);
        console.log(`[NOTIFY] ${ev.severity} → ${ev.to}: ${ev.subject}`);
        res.writeHead(204); res.end();
      } catch (e) {
        res.writeHead(400); res.end(e.message);
      }
    });
    return;
  }

  if (req.url === '/api/notifications' && req.method === 'GET') {
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify(LOG.slice(0, 50)));
  }

  res.writeHead(404); res.end('Not found');
});

server.listen(PORT, () => console.log(`Notification mock listening on :${PORT}`));
