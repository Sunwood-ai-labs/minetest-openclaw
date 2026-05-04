// Bridge server between OpenClaw agents and Minetest mod
// OpenClaw -> REST API -> Command Queue -> Minetest mod polls -> Execute in world

const express = require("express");
const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8080;

// State
const agentCommands = {};   // agent_id -> [command, ...]
const agentStates = {};     // agent_id -> {pos, is_moving, facing}
const agentLookResults = {}; // agent_id -> {surroundings}
const playerStates = {};     // player_name -> {pos}
const registeredAgents = new Set();

// Default triad (ONI-CADIA style)
const DEFAULT_AGENTS = ["iori", "tsumugi", "saku"];

DEFAULT_AGENTS.forEach((id) => registeredAgents.add(id));

//---------------------------------------------------------------
// Minetest Mod Endpoints (mod polls these)
//---------------------------------------------------------------

// Single sync endpoint: returns agents list + all pending commands
app.get("/api/sync", (req, res) => {
  const commands = [];
  for (const [agentId, queue] of Object.entries(agentCommands)) {
    while (queue.length > 0) {
      const cmd = queue.shift();
      cmd.agent_id = agentId;
      commands.push(cmd);
    }
  }

  res.json({
    agents: Array.from(registeredAgents),
    commands,
  });
});

// Mod reports agent state
app.post("/api/state/:agentId", (req, res) => {
  const { agentId } = req.params;
  agentStates[agentId] = req.body;
  res.json({ ok: true });
});

// Mod reports look results
app.post("/api/look/:agentId", (req, res) => {
  const { agentId } = req.params;
  agentLookResults[agentId] = req.body;
  res.json({ ok: true });
});

//---------------------------------------------------------------
// OpenClaw Agent Endpoints (agents call these)
//---------------------------------------------------------------

// Register a new agent
app.post("/api/agents", (req, res) => {
  const { agent_id } = req.body;
  if (!agent_id) return res.status(400).json({ error: "agent_id required" });

  registeredAgents.add(agent_id);
  agentCommands[agent_id] = agentCommands[agent_id] || [];
  res.json({ ok: true, agent_id });
});

// Get list of agents and their states
app.get("/api/agents", (req, res) => {
  const agents = {};
  for (const id of registeredAgents) {
    agents[id] = agentStates[id] || { pos: null, is_moving: false };
  }
  res.json(agents);
});

// Issue a command to an agent
app.post("/api/command/:agentId", (req, res) => {
  const { agentId } = req.params;
  if (!registeredAgents.has(agentId)) {
    return res.status(404).json({ error: "Agent not found. POST /api/agents first." });
  }

  const cmd = req.body;
  if (!cmd.action) return res.status(400).json({ error: "action required" });

  agentCommands[agentId] = agentCommands[agentId] || [];
  agentCommands[agentId].push(cmd);
  res.json({ ok: true, queued: cmd });
});

// Get agent state
app.get("/api/state/:agentId", (req, res) => {
  const { agentId } = req.params;
  const state = agentStates[agentId] || null;
  res.json({ agent_id: agentId, state });
});

// Get look results for an agent
app.get("/api/look/:agentId", (req, res) => {
  const { agentId } = req.params;
  const result = agentLookResults[agentId] || null;
  agentLookResults[agentId] = null; // Consume after reading
  res.json({ agent_id: agentId, look: result });
});

//---------------------------------------------------------------
// Convenience: combined action endpoint for OpenClaw skill
//---------------------------------------------------------------
app.post("/api/do/:agentId/:action", (req, res) => {
  const { agentId, action } = req.params;
  if (!registeredAgents.has(agentId)) {
    return res.status(404).json({ error: "Agent not found" });
  }

  const cmd = { action, ...req.body };
  agentCommands[agentId] = agentCommands[agentId] || [];
  agentCommands[agentId].push(cmd);
  res.json({ ok: true, action, agent_id: agentId });
});

//---------------------------------------------------------------
// Player position (reported by mod)
//---------------------------------------------------------------
app.post("/api/player/:name", (req, res) => {
  const { name } = req.params;
  playerStates[name] = req.body;
  res.json({ ok: true });
});

app.get("/api/player/:name", (req, res) => {
  const { name } = req.params;
  res.json(playerStates[name] || null);
});

//---------------------------------------------------------------
// Health
//---------------------------------------------------------------
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    agents: registeredAgents.size,
    pending_commands: Object.values(agentCommands).reduce((sum, q) => sum + q.length, 0),
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`[bridge] OpenClaw <-> Minetest bridge running on port ${PORT}`);
  console.log(`[bridge] Default agents: ${DEFAULT_AGENTS.join(", ")}`);
});
