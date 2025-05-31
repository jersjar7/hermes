// hermes-backend/server.js - Production-ready for long sessions

const WebSocket = require('ws');

const wss = new WebSocket.Server({ 
  port: 8080,
  // Configure for long-running connections
  perMessageDeflate: false,
  maxPayload: 16 * 1024, // 16KB max message size
  clientTracking: true,
  // Handle server-side ping/pong
  handleProtocols: (protocols, request) => {
    // Allow any protocol
    return protocols[0] || false;
  }
});

console.log('🚀 WebSocket server running on ws://localhost:8080');
console.log('📡 Ready for long-running conference sessions');

// Session management
const sessions = new Map(); // sessionId -> Set of clients
const clientInfo = new Map(); // client -> { sessionId, lastSeen, userId }

// Heartbeat configuration
const HEARTBEAT_INTERVAL = 30000; // 30 seconds
const CLIENT_TIMEOUT = 90000; // 90 seconds (3 missed heartbeats)

wss.on('connection', (socket, req) => {
  const sessionId = req.url.split('/').pop();
  const clientId = generateClientId();
  
  console.log(`✅ Client ${clientId} connected to session ${sessionId}`);
  
  // Initialize session if doesn't exist
  if (!sessions.has(sessionId)) {
    sessions.set(sessionId, new Set());
    console.log(`🆕 Created new session: ${sessionId}`);
  }
  
  // Add client to session
  sessions.get(sessionId).add(socket);
  clientInfo.set(socket, {
    sessionId,
    clientId,
    lastSeen: Date.now(),
    connectedAt: new Date().toISOString()
  });
  
  console.log(`👥 Session ${sessionId} now has ${sessions.get(sessionId).size} clients`);
  
  // Set up heartbeat immediately
  socket.isAlive = true;
  
  // Handle client pong responses
  socket.on('pong', () => {
    socket.isAlive = true;
    const info = clientInfo.get(socket);
    if (info) {
      info.lastSeen = Date.now();
    }
  });
  
  // Handle incoming messages
  socket.on('message', (data) => {
    const info = clientInfo.get(socket);
    if (!info) return;
    
    info.lastSeen = Date.now();
    
    try {
      const message = JSON.parse(data.toString());
      console.log(`📨 ${info.clientId}: ${message.type}`);
      
      // Broadcast to all other clients in the same session
      const sessionClients = sessions.get(info.sessionId);
      if (sessionClients) {
        sessionClients.forEach(client => {
          if (client !== socket && 
              client.readyState === WebSocket.OPEN) {
            client.send(data);
          }
        });
      }
    } catch (error) {
      console.error(`❌ Invalid message from ${info.clientId}:`, error);
    }
  });
  
  // Handle client disconnect
  socket.on('close', (code, reason) => {
    const info = clientInfo.get(socket);
    if (info) {
      console.log(`👋 Client ${info.clientId} disconnected from session ${info.sessionId} (code: ${code})`);
      
      // Remove from session
      const sessionClients = sessions.get(info.sessionId);
      if (sessionClients) {
        sessionClients.delete(socket);
        
        // Clean up empty sessions
        if (sessionClients.size === 0) {
          sessions.delete(info.sessionId);
          console.log(`🗑️  Cleaned up empty session: ${info.sessionId}`);
        } else {
          console.log(`👥 Session ${info.sessionId} now has ${sessionClients.size} clients`);
        }
      }
    }
    
    clientInfo.delete(socket);
  });
  
  // Handle client errors
  socket.on('error', (error) => {
    const info = clientInfo.get(socket);
    console.error(`❌ Socket error for ${info?.clientId || 'unknown'}:`, error.message);
  });
});

// Heartbeat system - ping all clients every 30 seconds
const heartbeatInterval = setInterval(() => {
  const now = Date.now();
  
  wss.clients.forEach(socket => {
    const info = clientInfo.get(socket);
    
    if (!socket.isAlive) {
      // Client didn't respond to last ping
      if (info) {
        console.log(`💔 Terminating unresponsive client ${info.clientId}`);
      }
      socket.terminate();
      return;
    }
    
    // Check if client is too old without communication
    if (info && (now - info.lastSeen) > CLIENT_TIMEOUT) {
      console.log(`⏰ Client ${info.clientId} timed out (last seen: ${new Date(info.lastSeen).toISOString()})`);
      socket.terminate();
      return;
    }
    
    // Send ping
    socket.isAlive = false;
    socket.ping();
  });
  
  // Log session statistics every 5 minutes
  if (Math.floor(now / 1000) % 300 === 0) {
    console.log(`📊 Active sessions: ${sessions.size}, Total clients: ${wss.clients.size}`);
  }
}, HEARTBEAT_INTERVAL);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down WebSocket server...');
  
  clearInterval(heartbeatInterval);
  
  // Close all connections gracefully
  wss.clients.forEach(socket => {
    socket.close(1000, 'Server shutting down');
  });
  
  wss.close(() => {
    console.log('✅ WebSocket server closed gracefully');
    process.exit(0);
  });
});

// Utility function
function generateClientId() {
  return Math.random().toString(36).substr(2, 8);
}

// Error handling
wss.on('error', (error) => {
  console.error('❌ WebSocket Server Error:', error);
});

console.log('💡 Server configured for long-running sessions (hours/days)');
console.log('🔄 Heartbeat: 30s interval, 90s timeout');
console.log('📱 Ready for iPhone + Simulator testing');