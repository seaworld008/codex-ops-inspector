# Ops Skill Bundle

Default model: `gpt-5.4`

Recommended Codex skills for this image and inspection scenario:

- `systematic-debugging`
- `senior-devops`
- `kubernetes-specialist`
- `observability-designer`
- `runbook-generator`
- `security-best-practices`
- `qa-expert`
- `github-ops`
- `sentry`
- `weather`

Usage recommendation:

1. Keep these skills in the image under `$CODEX_HOME/skills` when your runtime already manages a shared Codex skill directory.
2. If you mount an external Codex home, make sure the same skill names exist in the mounted path.
3. For pure Linux巡检, prioritize `systematic-debugging`, `senior-devops`, and `runbook-generator`.
4. For K8S巡检, prioritize `kubernetes-specialist`, `observability-designer`, and `security-best-practices`.

