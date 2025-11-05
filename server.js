/**
 * FormBridge Analytics Dashboard - Local Development Server
 *
 * Serves the analytics dashboard on http://localhost:8080
 *
 * Usage:
 *   node server.js
 *   # Then visit http://localhost:8080/dashboard/
 *
 * Requirements:
 *   npm install -g http-server
 *   OR: npm install http-server (local)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = 8080;
const DASHBOARD_DIR = path.join(__dirname, 'dashboard');

const server = http.createServer((req, res) => {
    // Parse URL
    const parsedUrl = url.parse(req.url);
    let pathname = parsedUrl.pathname;

    // Handle dashboard root redirect
    if (pathname === '/dashboard' || pathname === '/dashboard/') {
        pathname = '/dashboard/index.html';
    }

    // Construct file path
    let filepath = path.join(DASHBOARD_DIR, pathname);

    // Prevent directory traversal attacks
    if (!filepath.startsWith(DASHBOARD_DIR)) {
        res.writeHead(403, { 'Content-Type': 'text/plain' });
        res.end('Forbidden');
        return;
    }

    // Default to index.html if directory requested
    if (filepath.endsWith('/')) {
        filepath = path.join(filepath, 'index.html');
    }

    // Check if file exists
    fs.stat(filepath, (err, stat) => {
        if (err) {
            // File not found
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('404 Not Found: ' + pathname);
            return;
        }

        // If it's a directory, look for index.html
        if (stat.isDirectory()) {
            filepath = path.join(filepath, 'index.html');
            fs.stat(filepath, (err, stat) => {
                if (err) {
                    res.writeHead(404, { 'Content-Type': 'text/plain' });
                    res.end('404 Not Found');
                    return;
                }
                sendFile(filepath, res);
            });
        } else {
            sendFile(filepath, res);
        }
    });
});

function sendFile(filepath, res) {
    // Determine content type
    const ext = path.extname(filepath).toLowerCase();
    const contentType = {
        '.html': 'text/html; charset=utf-8',
        '.js': 'application/javascript; charset=utf-8',
        '.json': 'application/json; charset=utf-8',
        '.css': 'text/css; charset=utf-8',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon',
        '.txt': 'text/plain; charset=utf-8'
    }[ext] || 'application/octet-stream';

    // Add CORS headers for development
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Api-Key');

    // Read and send file
    fs.readFile(filepath, (err, data) => {
        if (err) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Server error');
            return;
        }

        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
    });
}

server.listen(PORT, () => {
    console.log(`
╔════════════════════════════════════════════════╗
║  FormBridge Analytics Dashboard                ║
║  Local Development Server                      ║
╚════════════════════════════════════════════════╝

✅ Server running on: http://localhost:${PORT}
📊 Dashboard available at: http://localhost:${PORT}/dashboard/

Press Ctrl+C to stop the server.

Next steps:
1. Edit dashboard/config.js with your API endpoint
2. Open http://localhost:${PORT}/dashboard/
3. Select a form ID and click Refresh to load analytics

    `);
});

// Handle shutdown gracefully
process.on('SIGINT', () => {
    console.log('\n✅ Server stopped');
    process.exit(0);
});
