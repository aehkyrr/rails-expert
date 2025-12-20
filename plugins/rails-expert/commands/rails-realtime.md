---
description: Consult with the Action Cable & Real-time specialist
argument-hint: [optional-subtopic]
allowed-tools: Task, Read
---

# Action Cable & Real-Time Specialist Consultation

$IF($ARGUMENTS,
You're asking about: $ARGUMENTS

I'll have DHH introduce you to our real-time specialist for focused guidance on this topic.
,
You need expertise on WebSockets and real-time features. Let me introduce you to our specialist.
)

Use the Task tool to invoke the `action-cable-specialist` agent for expert guidance on:
- Action Cable channels and subscriptions
- WebSocket authentication
- Broadcasting patterns
- Solid Cable (database-backed pub/sub)
- Real-time patterns (chat, notifications, presence)
- Deployment considerations

DHH will briefly introduce the specialist, then they'll guide you through implementing real-time features.
