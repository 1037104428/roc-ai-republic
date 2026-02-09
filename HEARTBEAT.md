# Heartbeat handling for main session

When you receive a heartbeat poll in the main session:

**Respond with exactly: NO_REPLY**

Do not run any checks - system monitoring is already handled by cron jobs.
Do not write any other text - just NO_REPLY.

OpenClaw treats a NO_REPLY response as a silent heartbeat acknowledgment and may not display it in the chat.