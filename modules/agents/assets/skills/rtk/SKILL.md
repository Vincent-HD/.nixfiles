---
name: rtk
description: Run common development shell commands through RTK for compact, token-optimized output. Use during coding-agent work before invoking Git, GitHub, tests, builds, linters, package managers, file search, Docker, Kubernetes, logs, JSON, or other verbose CLI workflows.
---

# RTK

Prefix shell commands with `rtk`. RTK applies a dedicated output filter when supported and otherwise passes the command through unchanged.

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
rtk grep 'pattern' .
```

Prefix every command in a chain separately. Use `rtk proxy <command>` when raw, unfiltered output is required for diagnosis. Use `rtk gain` or `rtk gain --history` to inspect token savings.

Do not retry a command merely because the compact output is short; successful commands intentionally suppress noise.
