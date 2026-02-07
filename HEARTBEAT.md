# HEARTBEAT.md

# Autonomous low-noise housekeeping loop

On each heartbeat:
1) Check `openclaw status` and `openclaw security audit` (fast mode).
2) If and only if there is a new warning/error/critical issue, send a short alert.
3) If no meaningful change, reply `HEARTBEAT_OK` only.

Noise control:
- Do not send routine "all good" messages.
- Batch non-urgent notes into a single weekly summary.
- Only interrupt immediately for security, connectivity, or data-loss risk.
