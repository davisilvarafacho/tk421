# AGENTS.md — Development Guidelines for AI Agents

Guidelines and integrations for AI coding agents (Antigravity, Claude Code, Codex, Cursor, etc.) working in `~/Development/quickshell`.

---

## 1. Core Operating Principles

### Karpathy Guidelines (`.agents/rules/karpathy-guidelines.md`)
- **Think Before Coding**: Do not assume, do not hide confusion, surface tradeoffs and clarify ambiguities before changing code.
- **Simplicity First**: Minimum code that solves the problem. Nothing speculative or over-engineered.
- **Surgical Changes**: Touch only what you must. Match surrounding style. Clean up only what your changes made unused.
- **Verify**: Define verifiable success criteria and test before declaring work complete.

### Ponytail Lazy Senior Dev Mode (`.agents/rules/ponytail.md`)
- The best code is the code you never wrote.
- Leverage standard libraries and existing components before introducing new abstractions.
- The shortest working, robust diff wins.

---

## 2. Integrated Skills & Tooling

### Graphify
Deterministic AST knowledge graph for codebase navigation:
- CLI command: `graphify query "<question>"`, `graphify path <node1> <node2>`, `graphify explain <symbol>`
- Rebuild/Update: `graphify update .`
- Interactive visual graph: `graphify-out/graph.html`
- Agent skill available at: `.agents/skills/graphify/`

### Trail (`@trailhq/trail-code`)
Team memory and semantic code mapping:
- CLI command: `trail ask "<query>"`, `trail note`, `trail check`, `trail status`
- Repository memory stored in: `.trail/learnings/`

### Superpowers
Methodical agent workflows available under `.agents/skills/`:
- `brainstorming`: Clarify requirements and draft design specs before coding.
- `writing-plans` & `executing-plans`: Incremental, verified implementation batches.
- `test-driven-development`: Write tests before implementation.
- `systematic-debugging`: Identify root causes without trial-and-error guessing.
- `subagent-driven-development`: Dispatch targeted subtasks.

### Codebase Memory (`codebase-memory-mcp`)
- Permanent daemon running locally on port **9749**.
- Graph exploration web UI: [http://127.0.0.1:9749](http://127.0.0.1:9749)
- MCP server configured globally in `~/.gemini/config/mcp_config.json`.
- CLI commands: `codebase-memory-mcp cli search_graph`, `codebase-memory-mcp cli query_graph`.

### Claude-Mem
- Persistent memory worker running locally on port **37700** (`~/.claude-mem`).
- Automatic observation and cross-session memory preservation.
