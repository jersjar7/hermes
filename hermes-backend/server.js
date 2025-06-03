// hermes-backend/server.js - Fixed for network access

const WebSocket = require('ws');

const wss = new WebSocket.Server({ 
  port: 8080,
  host: '0.0.0.0', // 🎯 FIXED: Listen on all interfaces, not just localhost
  perMessageDeflate: false,
  maxPayload: 16 * 1024,
  clientTracking: true,
  // Handle server-side ping/pong
  handleProtocols: (protocols, request) => {
    // Allow any protocol
    return protocols[0] || false;
  }
});

console.log('🚀 WebSocket server running on ws://0.0.0.0:8080');
console.log('🌐 Server accessible from network (not just localhost)');
console.log('📡 Ready for long-running conference sessions');
console.log('💡 Android devices can connect via your IP address');

// Session management
const sessions = new Map();
const clientInfo = new Map();

// Heartbeat configuration
const HEARTBEAT_INTERVAL = 30000;
const CLIENT_TIMEOUT = 90000;

wss.on('connection', (socket, req) => {
  const sessionId = req.url.split('/').pop();
  const clientId = generateClientId();
  
  console.log(`✅ Client ${clientId} connected to session ${sessionId}`);
  console.log(`🔗 Connection from: ${req.socket.remoteAddress}`);
  
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
    connectedAt: new Date().toISOString(),
    remoteAddress: req.socket.remoteAddress
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
      console.log(`⏰ Client ${info.clientId} timed out`);
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

console.log('🔄 Heartbeat: 30s interval, 90s timeout');
console.log('📱 Ready for Android + iOS testing');

// 🎯 ADDED: Show network info for easier debugging
const os = require('os');
const interfaces = os.networkInterfaces();
console.log('\n📍 Server accessible at:');
Object.keys(interfaces).forEach(ifname => {
  interfaces[ifname].forEach(iface => {
    if (iface.family === 'IPv4' && !iface.internal) {
      console.log(`   ws://${iface.address}:8080`);
    }
  });
});
console.log();