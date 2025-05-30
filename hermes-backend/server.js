// hermes-backend/server.js

const WebSocket = require('ws');

// No `path` option here—accept all upgrade requests on port 8080
const wss = new WebSocket.Server({ port: 8080 });

console.log('WebSocket server running on ws://localhost:8080/ws/{sessionId}');

wss.on('connection', (socket, req) => {
  // req.url will be '/ws/5TUXX9'
  const sessionId = req.url.split('/').pop();
  console.log(`Client connected for session ${sessionId}`);

  socket.on('message', (msg) => {
    // Broadcast only to clients on the same sessionId
    wss.clients.forEach((client) => {
      if (client !== socket &&
          client.readyState === WebSocket.OPEN &&
          client._socket.remoteAddress === socket._socket.remoteAddress // optional filter
      ) {
        client.send(msg);
      }
    });
  });

  socket.on('close', () => {
    console.log(`Client disconnected from session ${sessionId}`);
  });
});
