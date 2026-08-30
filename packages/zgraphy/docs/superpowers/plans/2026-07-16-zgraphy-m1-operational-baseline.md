# zgraphy M1 operational baseline implementation plan

1. Add a controlled Testing v2 scenario for deterministic publication,
   effective-config explanation, clean doctor output and stale-source detection.
2. Retain discovery and ownership evidence in `BuildResult` until publication.
3. Add config-v2 owned paths for content manifest and graph health.
4. Atomically encode deterministic manifest and health artifacts without host
   paths, timestamps or sensitive contents.
5. Add read-only doctor inspection, typed diagnostics and JSON encoding.
6. Wire `build`, `status` and `doctor` CLI behavior to the operational module.
7. Run the M1 scenarios, full Debug/ReleaseSafe suites, safety policy and agent
   project checks; inspect Testing v2 receipts before promoting M1 requirements.

