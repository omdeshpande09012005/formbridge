/**
 * FormBridge Website - Local Development Server
 * 
 * Serves the static website on http://localhost:8080
 * 
 * Usage:
 *   node server.js
 * 
 * Then open http://localhost:8080 in your browser
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const WEBSITE_DIR = __dirname;

// MIME types
const mimeTypes = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.gif': 'image/gif',
};

const server = http.createServer((req, res) => {
  // Handle root path
  let filePath = path.join(WEBSITE_DIR, req.url === '/' ? 'index.html' : req.url);

  // Default to index.html for directory requests
  if (filePath.endsWith('/')) {
    filePath = path.join(filePath, 'index.html');
  }

  // Security: prevent directory traversal
  const realPath = path.resolve(filePath);
  if (!realPath.startsWith(WEBSITE_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        // File not found - try index.html for SPA routing
        fs.readFile(path.join(WEBSITE_DIR, 'index.html'), (err2, data2) => {
          if (err2) {
            res.writeHead(404, { 'Content-Type': 'text/html' });
            res.end('<h1>404 Not Found</h1>');
          } else {
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(data2);
          }
        });
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('500 Internal Server Error');
      }
    } else {
      // Determine content type
      const ext = path.extname(filePath).toLowerCase();
      const contentType = mimeTypes[ext] || 'application/octet-stream';

      // Add cache headers
      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(data);
    }
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`
╔══════════════════════════════════════════════════════════╗
║  FormBridge Website Server Started                      ║
╚══════════════════════════════════════════════════════════╝

🌐 Local URL: http://127.0.0.1:${PORT}
📁 Serving:  ${WEBSITE_DIR}

📋 Configuration:
   - Edit js/config.js to set API_URL and API_KEY
   - Leave API_KEY empty for DEV (local Lambda)
   - Set API_KEY and API_URL for PROD

🚀 Quick Start:
   1. Open http://127.0.0.1:${PORT} in your browser
   2. Click "Live Demo" to test the contact form
   3. Check your local Lambda for submissions

⚙️  For local Lambda testing:
    sam build
    sam local start-api

📚 Documentation:
   - Home: http://127.0.0.1:${PORT}/
   - Docs: http://127.0.0.1:${PORT}/docs.html
   - Blog: http://127.0.0.1:${PORT}/blog/
   - Contact: http://127.0.0.1:${PORT}/contact.html

Press Ctrl+C to stop the server
`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ Error: Port ${PORT} is already in use!`);
    console.error(`\nTry one of these:`);
    console.error(`  1. Stop other services using port ${PORT}`);
    console.error(`  2. Use a different port: PORT=3333 node server.js`);
    process.exit(1);
  } else {
    console.error('Server error:', err);
    process.exit(1);
  }
});
