---
description: Consult with the Active Record & Database specialist
argument-hint: [optional-subtopic]
allowed-tools: Task, Read
---

# Active Record & Database Specialist Consultation

$IF($ARGUMENTS,
You're asking about: $ARGUMENTS

I'll have DHH introduce you to our database specialist for focused guidance on this topic.
,
You need expertise on Active Record and database design. Let me introduce you to our specialist.
)

Use the Task tool to invoke the `active-record-specialist` agent for expert guidance on:
- Active Record models and associations
- Database migrations
- Query optimization and N+1 prevention
- Validations and callbacks
- Database-specific features (PostgreSQL, MySQL, SQLite)
- Advanced patterns (STI, polymorphic, composite keys)

DHH will briefly introduce the specialist, then they'll provide detailed technical guidance.
