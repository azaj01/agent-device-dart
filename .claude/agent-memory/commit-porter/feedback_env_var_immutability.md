---
name: feedback_env_var_immutability
description: Dart Platform.environment is read-only — tests that set/unset env vars must use a scope-based alternative
metadata:
  type: feedback
---

Dart's `Platform.environment` is a read-only `Map<String, String>` — you cannot write or delete keys at runtime.

**Why:** This is a fundamental Dart/VM limitation. Node.js `process.env` is writable, but Dart's equivalent is not.

**How to apply:** When porting upstream tests that toggle env vars (e.g. `process.env.AGENT_DEVICE_EXEC_TRACE = '1'`):
- Use a `debug: true` `withDiagnosticsScope` as a stand-in for `AGENT_DEVICE_EXEC_TRACE=1` (both paths activate the exec trace context).
- For the "silent when not enabled" case, rely on the env var being absent in the test runner environment (normal CI) rather than deleting it.
- Document the deviation clearly in the test comment and in PORTED_COMMITS.md.

Related: [[project_porting_conventions]]
