// VaultGuard Agent ULTIMATE
// - Heartbeat every 30s
// - Never exits on uncaught errors; logs locally
// - Designed to be started by Windows Scheduled Task

const fs = require('fs');
const path = require('path');

const logFile = path.join(__dirname, 'agent_ultimate.log');

function stamp() {
  return new Date().toISOString();
}

function log(msg) {
  const entry = `[${stamp()}] ${msg}\n`;
  try { console.log(entry.trim()); } catch (_) {}
  try { fs.appendFileSync(logFile, entry, 'utf8'); } catch (_) {}
}

log('AGENT_ULTIMATE_START');

setInterval(() => log('HEARTBEAT'), 30_000);

process.on('uncaughtException', (err) => {
  log(`UNCAUGHT: ${err && err.message ? err.message : String(err)}`);
});

process.on('unhandledRejection', (reason) => {
  log(`UNHANDLED_REJECTION: ${reason && reason.message ? reason.message : String(reason)}`);
});

