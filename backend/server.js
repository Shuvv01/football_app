const http = require('http');
const fs = require('fs/promises');
const path = require('path');

const PORT = 3000;
const ADMIN_EMAIL = 'shuvamgtm11@gmail.com';
const DATA_FILE = path.join(__dirname, 'data.json');
const COLLECTIONS = new Set(['players', 'matches', 'news', 'updates', 'formations', 'members']);

async function readData() {
  const raw = await fs.readFile(DATA_FILE, 'utf8');
  return JSON.parse(raw);
}

async function writeData(data) {
  await fs.writeFile(DATA_FILE, JSON.stringify(data, null, 2));
}

function sendJson(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,x-admin-email',
  });
  res.end(JSON.stringify(body));
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(error);
      }
    });
  });
}

function isAdminRequest(req) {
  return (req.headers['x-admin-email'] || '').toLowerCase() === ADMIN_EMAIL;
}

function makeId(prefix) {
  return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}

async function handleAuth(req, res) {
  const body = await parseBody(req);
  const email = String(body.email || '').trim().toLowerCase();
  const memberId = String(body.memberId || '').trim();

  if (!email) {
    sendJson(res, 400, { error: 'Email is required.' });
    return;
  }

  const data = await readData();
  let member = data.members.find((item) => item.email.toLowerCase() === email);

  if (!member) {
    member = {
      id: makeId('member'),
      email,
      memberId: memberId || `SFC-${Date.now().toString().slice(-5)}`,
      role: email === ADMIN_EMAIL ? 'admin' : 'member',
      joinedAt: new Date().toISOString(),
    };
    data.members.push(member);
    await writeData(data);
  }

  sendJson(res, 200, {
    user: member,
    isAdmin: member.role === 'admin',
    message: member.role === 'admin' ? 'Owner admin login successful.' : 'Member login successful.',
  });
}

async function handleCollection(req, res, collection, id) {
  const data = await readData();

  if (!COLLECTIONS.has(collection)) {
    sendJson(res, 404, { error: 'Unknown API collection.' });
    return;
  }

  if (req.method === 'GET') {
    sendJson(res, 200, data[collection]);
    return;
  }

  if (!isAdminRequest(req)) {
    sendJson(res, 403, { error: 'Admin access required.' });
    return;
  }

  if (req.method === 'POST') {
    const body = await parseBody(req);
    const item = { ...body, id: body.id || makeId(collection.slice(0, 1)) };
    data[collection].push(item);
    await writeData(data);
    sendJson(res, 201, item);
    return;
  }

  if (req.method === 'PUT') {
    if (!id) {
      sendJson(res, 400, { error: 'Item id is required.' });
      return;
    }

    const body = await parseBody(req);
    const index = data[collection].findIndex((item) => item.id === id);

    if (index === -1) {
      sendJson(res, 404, { error: 'Item not found.' });
      return;
    }

    data[collection][index] = { ...data[collection][index], ...body, id };
    await writeData(data);
    sendJson(res, 200, data[collection][index]);
    return;
  }

  if (req.method === 'DELETE') {
    if (!id) {
      sendJson(res, 400, { error: 'Item id is required.' });
      return;
    }

    data[collection] = data[collection].filter((item) => item.id !== id);
    await writeData(data);
    sendJson(res, 200, { ok: true });
    return;
  }

  sendJson(res, 405, { error: 'Method not allowed.' });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    sendJson(res, 204, {});
    return;
  }

  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const parts = url.pathname.split('/').filter(Boolean);

    if (url.pathname === '/api/health') {
      sendJson(res, 200, { ok: true, club: 'SHUVAM FC' });
      return;
    }

    if (url.pathname === '/api/auth/login' && req.method === 'POST') {
      await handleAuth(req, res);
      return;
    }

    if (parts[0] === 'api' && parts[1]) {
      await handleCollection(req, res, parts[1], parts[2]);
      return;
    }

    sendJson(res, 404, { error: 'Route not found.' });
  } catch (error) {
    sendJson(res, 500, { error: error.message || 'Server error.' });
  }
});

server.listen(PORT, () => {
  console.log(`SHUVAM FC backend running at http://localhost:${PORT}`);
  console.log(`Admin email: ${ADMIN_EMAIL}`);
});

